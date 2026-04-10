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
  permissions => #{OwnerId => owner},
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
  {ok, ?DEFAULT_STATE(VaultId, OwnerId, Now), ?INACTIVITY_TIMEOUT}.

handle_call({grant_access, UserId}, _From, State) ->
  Permissions = maps:get(permissions, State),
  NewPermissions = Permissions#{UserId => read},
  UpdatedState = State#{
    permissions => NewPermissions,
    updated_at  => erlang:system_time(millisecond)
  },
  {reply, {ok, granted}, UpdatedState, ?INACTIVITY_TIMEOUT};

handle_call({revoke_access, UserId}, _From, State) ->
  Permissions = maps:get(permissions, State),
  NewPermissions = maps:remove(UserId, Permissions),
  UpdatedState = State#{
    permissions => NewPermissions,
    updated_at  => erlang:system_time(millisecond)
  },
  {reply, {ok, revoked}, UpdatedState, ?INACTIVITY_TIMEOUT};

handle_call({store_shard, ShardId, EncryptedBlob, CallerId}, _From, State) ->
  case check_permission(CallerId, write, maps:get(permissions, State)) of
    ok ->
      NewShards = (maps:get(shards, State))#{ShardId => EncryptedBlob},
      UpdatedState = State#{
        shards     => NewShards,
        updated_at => erlang:system_time(millisecond)
      },
      {reply, {ok, ShardId}, UpdatedState, ?INACTIVITY_TIMEOUT};
    {error, unauthorized} ->
      {reply, {error, unauthorized}, State, ?INACTIVITY_TIMEOUT}
  end;

handle_call({get_shard, ShardId, CallerId}, _From, State) ->
  case check_permission(CallerId, read, maps:get(permissions, State)) of
    ok ->
      case maps:find(ShardId, maps:get(shards, State)) of
        {ok, EncryptedBlob} ->
          {reply, {ok, EncryptedBlob}, State, ?INACTIVITY_TIMEOUT};
        error ->
          {reply, {error, shard_not_found}, State, ?INACTIVITY_TIMEOUT}
      end;
    {error, unauthorized} ->
      {reply, {error, unauthorized}, State, ?INACTIVITY_TIMEOUT}
  end;

handle_call(list_shards, _From, State) ->
  ShardIds = maps:keys(maps:get(shards, State)),
  {reply, {ok, ShardIds}, State, ?INACTIVITY_TIMEOUT};

handle_call(get_vault_permissions, _From, State) ->
  {reply, {ok, maps:get(permissions, State)}, State, ?INACTIVITY_TIMEOUT};

handle_call(_Request, _From, State) ->
  {reply, {error, unknown_call}, State, ?INACTIVITY_TIMEOUT}.

handle_cast(_Request, State) ->
  {noreply, State, ?INACTIVITY_TIMEOUT}.

%% Timeout: save state to DB and terminate
handle_info(timeout, State) ->
  VaultId = maps:get(vault_id, State),
  case vault_db:store_vault(VaultId, State) of
    {ok, _} ->
      logger:info("Vault ~p saved to DB before timeout", [VaultId]);
    {error, Reason} ->
      logger:error("Failed to save vault ~p to DB: ~p", [VaultId, Reason])
  end,
  {stop, normal, State};

handle_info(_Info, State) ->
  {noreply, State, ?INACTIVITY_TIMEOUT}.

terminate(_Reason, State) ->
  VaultId = maps:get(vault_id, State),
  % Ensure state is saved to CouchDB before terminating (in case not saved via timeout)
  case vault_db:store_vault(VaultId, State) of
    {ok, _} ->
      logger:info("Vault ~p saved to DB on termination", [VaultId]);
    {error, Reason} ->
      logger:error("Failed to save vault ~p to DB on termination: ~p", [VaultId, Reason])
  end,
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%% ===================================================================
%% Internal functions
%% ===================================================================

check_permission(CallerId, write, Permissions) ->
  case maps:get(CallerId, Permissions, none) of
    owner -> ok;
    _     -> {error, unauthorized}
  end;
check_permission(CallerId, read, Permissions) ->
  case maps:get(CallerId, Permissions, none) of
    none -> {error, unauthorized};
    _    -> ok
  end.
