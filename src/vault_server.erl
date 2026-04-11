%%%-------------------------------------------------------------------
%% @doc Vault server implementation - gen_server for vault instance
%% Each vault is a separate process with independent state
%% Timeout mechanism: inactive vault saves state to DB and terminates
%%%-------------------------------------------------------------------
-module(vault_server).

-behaviour(gen_server).

%% Public API
-export([
    start_link/2
]).

%% gen_server callbacks
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

% 5 minutes in milliseconds
-define(INACTIVITY_TIMEOUT, 300000).

-define(DEFAULT_STATE(VaultId, OwnerId, Now), #{
    vault_id => VaultId,
    owner_id => OwnerId,
    permissions => #{hash_id(OwnerId) => <<"owner">>},
    created_at => Now,
    updated_at => Now
}).

%% ===================================================================
%% Public API
%% ===================================================================

%% @doc Start a vault server process with the given vault_id and owner_id
-spec start_link(binary(), binary()) -> {ok, pid()} | {error, term()}.
start_link(VaultId, OwnerId) ->
    gen_server:start_link(?MODULE, {VaultId, OwnerId}, []).

%% ===================================================================
%% gen_server callbacks
%% ===================================================================

init({VaultId, OwnerId}) ->
    Now = erlang:system_time(millisecond),
    State = restore_or_create(VaultId, OwnerId, Now),
    {ok, State, ?INACTIVITY_TIMEOUT}.

handle_call(
    {grant_access, CallerId, UserId},
    _From,
    #{vault_id := VaultId, permissions := Permissions} = State
) ->
    case can_write(CallerId, Permissions) of
        ok ->
            NewPermissions = Permissions#{hash_id(UserId) => <<"read">>},
            UpdatedState = State#{
                permissions => NewPermissions,
                updated_at => erlang:system_time(millisecond)
            },
            vault_audit:log_access(
                VaultId, CallerId, <<"grant_access">>, erlang:system_time(millisecond)
            ),
            {reply, {ok, granted}, UpdatedState, ?INACTIVITY_TIMEOUT};
        {error, unauthorized} ->
            {reply, {error, unauthorized}, State, ?INACTIVITY_TIMEOUT}
    end;
handle_call(
    {revoke_access, CallerId, UserId},
    _From,
    #{vault_id := VaultId, permissions := Permissions} = State
) ->
    case can_write(CallerId, Permissions) of
        ok ->
            NewPermissions = maps:remove(hash_id(UserId), Permissions),
            UpdatedState = State#{
                permissions => NewPermissions,
                updated_at => erlang:system_time(millisecond)
            },
            vault_audit:log_access(
                VaultId, CallerId, <<"revoke_access">>, erlang:system_time(millisecond)
            ),
            {reply, {ok, revoked}, UpdatedState, ?INACTIVITY_TIMEOUT};
        {error, unauthorized} ->
            {reply, {error, unauthorized}, State, ?INACTIVITY_TIMEOUT}
    end;
handle_call(
    {store_shard, ShardId, EncryptedBlob, CallerId},
    _From,
    #{vault_id := VaultId, permissions := Permissions} = State
) ->
    case can_write(CallerId, Permissions) of
        ok ->
            case vault_shards:store_shard(VaultId, ShardId, #{<<"data">> => EncryptedBlob}) of
                {ok, _} ->
                    vault_audit:log_access(
                        VaultId, CallerId, <<"store_shard">>, erlang:system_time(millisecond)
                    ),
                    {reply, {ok, ShardId}, State#{updated_at => erlang:system_time(millisecond)},
                        ?INACTIVITY_TIMEOUT};
                {error, Reason} ->
                    {reply, {error, Reason}, State, ?INACTIVITY_TIMEOUT}
            end;
        {error, unauthorized} ->
            {reply, {error, unauthorized}, State, ?INACTIVITY_TIMEOUT}
    end;
handle_call(
    {get_shard, ShardId, CallerId},
    _From,
    #{vault_id := VaultId, permissions := Permissions} = State
) ->
    Reply =
        case can_read(CallerId, Permissions) of
            ok ->
                vault_audit:log_access(
                    VaultId, CallerId, <<"get_shard">>, erlang:system_time(millisecond)
                ),
                fetch_shard(VaultId, ShardId);
            {error, _} = E ->
                E
        end,
    {reply, Reply, State, ?INACTIVITY_TIMEOUT};
handle_call(
    {get_all_shards, CallerId},
    _From,
    #{vault_id := VaultId, permissions := Permissions} = State
) ->
    Reply =
        case can_read(CallerId, Permissions) of
            ok ->
                vault_audit:log_access(
                    VaultId, CallerId, <<"get_all_shards">>, erlang:system_time(millisecond)
                ),
                fetch_all_shards(VaultId);
            {error, _} = E ->
                E
        end,
    {reply, Reply, State, ?INACTIVITY_TIMEOUT};
handle_call(get_vault_permissions, _From, #{permissions := Permissions} = State) ->
    {reply, {ok, Permissions}, State, ?INACTIVITY_TIMEOUT};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State, ?INACTIVITY_TIMEOUT}.

handle_cast(_Request, State) ->
    {noreply, State, ?INACTIVITY_TIMEOUT}.

%% Timeout: save metadata to DB and terminate
handle_info(timeout, #{vault_id := VaultId} = State) ->
    save_metadata(VaultId, State),
    {stop, normal, State};
handle_info(_Info, State) ->
    {noreply, State, ?INACTIVITY_TIMEOUT}.

terminate(_Reason, #{vault_id := VaultId} = State) ->
    save_metadata(VaultId, State),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ===================================================================
%% Internal functions
%% ===================================================================

-define(HASH_ALGORITHM, sha256).

hash_id(UserId) ->
    crypto:hash(?HASH_ALGORITHM, UserId).

can_write(CallerId, Permissions) ->
    HashedId = hash_id(CallerId),
    case Permissions of
        #{HashedId := <<"owner">>} -> ok;
        _ -> {error, unauthorized}
    end.

can_read(CallerId, Permissions) ->
    HashedId = hash_id(CallerId),
    case Permissions of
        #{HashedId := _} -> ok;
        _ -> {error, unauthorized}
    end.

fetch_shard(VaultId, ShardId) ->
    case vault_shards:get_shard(VaultId, ShardId) of
        {ok, Doc} ->
            #{<<"data">> := Blob} = vault_db:ejson_to_map(Doc),
            {ok, Blob};
        {error, not_found} ->
            {error, shard_not_found};
        {error, _} = E ->
            E
    end.

fetch_all_shards(VaultId) ->
    case vault_shards:get_all_shards_for_vault(VaultId) of
        {ok, Docs} ->
            Shards =
                #{
                    extract_shard_id(VaultId, maps:get(<<"_id">>, M)) =>
                        maps:get(<<"data">>, M)
                 || Doc <- Docs,
                    M <- [vault_db:ejson_to_map(Doc)]
                },
            {ok, Shards};
        {error, _} = E ->
            E
    end.

%% Restore vault state from CouchDB, or create fresh state if not found/unavailable
restore_or_create(VaultId, OwnerId, Now) ->
    case vault_db:get_vault(VaultId) of
        {ok, Doc} ->
            restore_state(VaultId, Doc);
        {error, not_found} ->
            ?DEFAULT_STATE(VaultId, OwnerId, Now);
        {error, Reason} ->
            logger:warning("Could not restore vault ~p from DB: ~p — starting fresh", [
                VaultId, Reason
            ]),
            ?DEFAULT_STATE(VaultId, OwnerId, Now)
    end.

%% Convert a CouchDB vault doc back to in-memory state map
restore_state(VaultId, Doc) ->
    State = vault_db:ejson_to_map(Doc),
    #{
        vault_id => VaultId,
        owner_id => maps:get(<<"owner_id">>, State, undefined),
        permissions => maps:get(<<"permissions">>, State, #{}),
        created_at => maps:get(<<"created_at">>, State, erlang:system_time(millisecond)),
        updated_at => maps:get(<<"updated_at">>, State, erlang:system_time(millisecond))
    }.

%% Strip the "shard:VaultId:" prefix to recover the ShardId
extract_shard_id(VaultId, DocId) ->
    PrefixLen = byte_size(<<"shard:">>) + byte_size(VaultId) + 1,
    binary:part(DocId, PrefixLen, byte_size(DocId) - PrefixLen).

%% Save vault metadata to CouchDB
save_metadata(VaultId, State) ->
    case vault_db:store_vault(VaultId, State) of
        {ok, _} ->
            logger:info("Vault ~p metadata saved to DB", [VaultId]),
            ok;
        {error, Reason} ->
            logger:error("Failed to save vault ~p metadata: ~p", [VaultId, Reason]),
            {error, Reason}
    end.
