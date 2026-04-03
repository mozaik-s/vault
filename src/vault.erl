%%%-------------------------------------------------------------------
%% @doc Vault gen_server - manages a single vault instance
%% Each vault is a separate process with independent state
%% Timeout mechanism: inactive vault saves state to DB and terminates
%%%-------------------------------------------------------------------
-module(vault).

-behaviour(gen_server).

%% API
-export([
  start_link/2,
  grant_shard_access/3,
  revoke_shard_access/3,
  store_shard/3,
  get_shard/2,
  list_shards/1,
  get_permissions/1
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

-record(state, {
  vault_id :: binary(),
  owner_id :: binary(),
  shards = #{} :: map(),
  permissions = #{} :: map(),
  audit_trail = [] :: list(),
  created_at :: integer(),
  updated_at :: integer()
}).

%% ===================================================================
%% API
%% ===================================================================

%% @doc Start a vault process with the given vault_id and owner_id
-spec start_link(binary(), binary()) -> {ok, pid()} | {error, term()}.
start_link(VaultId, OwnerId) ->
  gen_server:start_link(?MODULE, {VaultId, OwnerId}, []).

%% @doc Grant a user access to specific shards
-spec grant_shard_access(pid(), binary(), list()) -> {ok, granted} | {error, term()}.
grant_shard_access(VaultPid, UserId, ShardIds) ->
  gen_server:call(VaultPid, {grant_shard_access, UserId, ShardIds}).

%% @doc Revoke a user's access to shards
-spec revoke_shard_access(pid(), binary(), list()) -> {ok, revoked} | {error, term()}.
revoke_shard_access(VaultPid, UserId, ShardIds) ->
  gen_server:call(VaultPid, {revoke_shard_access, UserId, ShardIds}).

%% @doc Store an encrypted shard
-spec store_shard(pid(), binary(), binary()) -> {ok, binary()} | {error, term()}.
store_shard(VaultPid, ShardId, EncryptedBlob) ->
  gen_server:call(VaultPid, {store_shard, ShardId, EncryptedBlob}).

%% @doc Retrieve an encrypted shard
-spec get_shard(pid(), binary()) -> {ok, binary()} | {error, term()}.
get_shard(VaultPid, ShardId) ->
  gen_server:call(VaultPid, {get_shard, ShardId}).

%% @doc List all shard IDs in vault
-spec list_shards(pid()) -> {ok, list()} | {error, term()}.
list_shards(VaultPid) ->
  gen_server:call(VaultPid, list_shards).

%% @doc Get all permissions for vault
-spec get_permissions(pid()) -> {ok, map()} | {error, term()}.
get_permissions(VaultPid) ->
  gen_server:call(VaultPid, get_permissions).

%% ===================================================================
%% gen_server callbacks
%% ===================================================================

init({VaultId, OwnerId}) ->
  Now = erlang:system_time(millisecond),
  State = #state{
    vault_id = VaultId,
    owner_id = OwnerId,
    created_at = Now,
    updated_at = Now
  },
  {ok, State, ?INACTIVITY_TIMEOUT}.

handle_call({grant_shard_access, UserId, ShardIds}, _From, State) ->
  % Placeholder: grant access to shards for user
  % TODO: Implement signature verification and permission storage
  UpdatedState = State#state{updated_at = erlang:system_time(millisecond)},
  {reply, {ok, granted}, UpdatedState, ?INACTIVITY_TIMEOUT};

handle_call({revoke_shard_access, UserId, ShardIds}, _From, State) ->
  % Placeholder: revoke access to shards for user
  % TODO: Implement revocation logic
  UpdatedState = State#state{updated_at = erlang:system_time(millisecond)},
  {reply, {ok, revoked}, UpdatedState, ?INACTIVITY_TIMEOUT};

handle_call({store_shard, ShardId, EncryptedBlob}, _From, State) ->
  % Placeholder: store encrypted shard
  % TODO: Implement shard hashing and storage
  Shards = State#state.shards,
  NewShards = Shards#{ShardId => EncryptedBlob},
  UpdatedState = State#state{
    shards = NewShards,
    updated_at = erlang:system_time(millisecond)
  },
  {reply, {ok, ShardId}, UpdatedState, ?INACTIVITY_TIMEOUT};

handle_call({get_shard, ShardId}, _From, State) ->
  Shards = State#state.shards,
  case maps:find(ShardId, Shards) of
    {ok, EncryptedBlob} ->
      {reply, {ok, EncryptedBlob}, State, ?INACTIVITY_TIMEOUT};
    error ->
      {reply, {error, shard_not_found}, State, ?INACTIVITY_TIMEOUT}
  end;

handle_call(list_shards, _From, State) ->
  ShardIds = maps:keys(State#state.shards),
  {reply, {ok, ShardIds}, State, ?INACTIVITY_TIMEOUT};

handle_call(get_permissions, _From, State) ->
  {reply, {ok, State#state.permissions}, State, ?INACTIVITY_TIMEOUT};

handle_call(_Request, _From, State) ->
  {reply, {error, unknown_call}, State, ?INACTIVITY_TIMEOUT}.

handle_cast(_Request, State) ->
  {noreply, State, ?INACTIVITY_TIMEOUT}.

%% Timeout: save state to DB and terminate
handle_info(timeout, State) ->
  VaultId = State#state.vault_id,
  % TODO: Save state to CouchDB via vault_db module
  logger:info("Vault ~p timed out, saving state to DB", [VaultId]),
  {stop, normal, State};

handle_info(_Info, State) ->
  {noreply, State, ?INACTIVITY_TIMEOUT}.

terminate(_Reason, State) ->
  VaultId = State#state.vault_id,
  % TODO: Ensure state is saved to CouchDB before terminating
  logger:info("Vault ~p terminating", [VaultId]),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
