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

-define(INACTIVITY_TIMEOUT, 300000).  % 5 minutes in milliseconds

-define(DEFAULT_STATE(VaultId, OwnerId, Now), #{
  vault_id    => VaultId,
  owner_id    => OwnerId,
  shards      => #{},
  permissions => #{OwnerId => <<"owner">>},
  audit_trail => [],
  created_at  => Now,
  updated_at  => Now
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

handle_call({grant_access, UserId}, _From, #{permissions := Permissions} = State) ->
  NewPermissions = Permissions#{UserId => <<"read">>},
  UpdatedState = State#{
    permissions => NewPermissions,
    updated_at  => erlang:system_time(millisecond)
  },
  {reply, {ok, granted}, UpdatedState, ?INACTIVITY_TIMEOUT};

handle_call({revoke_access, UserId}, _From, #{permissions := Permissions} = State) ->
  NewPermissions = maps:remove(UserId, Permissions),
  UpdatedState = State#{
    permissions => NewPermissions,
    updated_at  => erlang:system_time(millisecond)
  },
  {reply, {ok, revoked}, UpdatedState, ?INACTIVITY_TIMEOUT};

handle_call({store_shard, ShardId, EncryptedBlob, CallerId}, _From,
            #{vault_id := VaultId, permissions := Permissions, shards := Shards} = State) ->
  case check_permission(CallerId, write, Permissions) of
    ok ->
      persist_shard(VaultId, ShardId, EncryptedBlob),
      UpdatedState = State#{
        shards     => Shards#{ShardId => EncryptedBlob},
        updated_at => erlang:system_time(millisecond)
      },
      {reply, {ok, ShardId}, UpdatedState, ?INACTIVITY_TIMEOUT};
    {error, unauthorized} ->
      {reply, {error, unauthorized}, State, ?INACTIVITY_TIMEOUT}
  end;

handle_call({get_shard, ShardId, CallerId}, _From,
            #{permissions := Permissions, shards := Shards} = State) ->
  case check_permission(CallerId, read, Permissions) of
    ok ->
      case maps:find(ShardId, Shards) of
        {ok, EncryptedBlob} ->
          {reply, {ok, EncryptedBlob}, State, ?INACTIVITY_TIMEOUT};
        error ->
          {reply, {error, shard_not_found}, State, ?INACTIVITY_TIMEOUT}
      end;
    {error, unauthorized} ->
      {reply, {error, unauthorized}, State, ?INACTIVITY_TIMEOUT}
  end;

handle_call(list_shards, _From, #{shards := Shards} = State) ->
  {reply, {ok, maps:keys(Shards)}, State, ?INACTIVITY_TIMEOUT};

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

check_permission(CallerId, write, Permissions) ->
  case maps:get(CallerId, Permissions, undefined) of
    <<"owner">> -> ok;
    _           -> {error, unauthorized}
  end;
check_permission(CallerId, read, Permissions) ->
  case maps:get(CallerId, Permissions, undefined) of
    undefined -> {error, unauthorized};
    _         -> ok
  end.

%% Restore vault state from CouchDB, or create fresh state if not found/unavailable
restore_or_create(VaultId, OwnerId, Now) ->
  case vault_db:get_vault(VaultId) of
    {ok, Doc} ->
      restore_state(VaultId, Doc);
    {error, not_found} ->
      ?DEFAULT_STATE(VaultId, OwnerId, Now);
    {error, Reason} ->
      logger:warning("Could not restore vault ~p from DB: ~p — starting fresh", [VaultId, Reason]),
      ?DEFAULT_STATE(VaultId, OwnerId, Now)
  end.

%% Convert a CouchDB vault doc back to in-memory state map (no shards — loaded on demand)
restore_state(VaultId, Doc) ->
  State = vault_db:ejson_to_map(Doc),
  #{
    vault_id    => VaultId,
    owner_id    => maps:get(<<"owner_id">>,    State, undefined),
    shards      => #{},
    permissions => maps:get(<<"permissions">>, State, #{}),
    audit_trail => maps:get(<<"audit_trail">>, State, []),
    created_at  => maps:get(<<"created_at">>,  State, erlang:system_time(millisecond)),
    updated_at  => maps:get(<<"updated_at">>,  State, erlang:system_time(millisecond))
  }.

%% Persist a shard to CouchDB (best-effort — errors are logged, not propagated)
persist_shard(VaultId, ShardId, EncryptedBlob) ->
  case vault_shards:store_shard(VaultId, ShardId, #{<<"data">> => EncryptedBlob}) of
    {ok, _} ->
      ok;
    {error, Reason} ->
      logger:error("Failed to persist shard ~p:~p — ~p", [VaultId, ShardId, Reason])
  end.

%% Save vault metadata (without shards) to CouchDB — shards are persisted individually
save_metadata(VaultId, State) ->
  Metadata = maps:remove(shards, State),
  case vault_db:store_vault(VaultId, Metadata) of
    {ok, _} ->
      logger:info("Vault ~p metadata saved to DB", [VaultId]);
    {error, Reason} ->
      logger:error("Failed to save vault ~p metadata: ~p", [VaultId, Reason])
  end.
