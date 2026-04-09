%%%-------------------------------------------------------------------
%% @doc Vault shard management - business logic for shard operations
%% Owns the shard document ID scheme: "shard:VaultId:ShardId"
%% Delegates low-level CouchDB operations to vault_db
%%%-------------------------------------------------------------------
-module(vault_shards).

-export([
  store_shard/3,
  get_shard/2,
  get_all_shards_for_vault/1,
  delete_shard/2
]).

-define(SHARD_PREFIX, <<"shard:">>).

%% @doc Store shard data for a given vault
-spec store_shard(binary(), binary(), map()) -> {ok, term()} | {error, term()}.
store_shard(VaultId, ShardId, ShardData) ->
  logger:debug("Storing shard ~p:~p", [VaultId, ShardId]),
  DocId = shard_doc_id(VaultId, ShardId),
  Doc = ShardData#{<<"_id">> => DocId, <<"type">> => <<"shard">>, <<"vault_id">> => VaultId},
  case vault_db:store_doc(DocId, Doc) of
    {ok, Saved} ->
      logger:debug("Shard ~p:~p stored successfully", [VaultId, ShardId]),
      {ok, Saved};
    Error ->
      logger:error("Failed to store shard ~p:~p: ~p", [VaultId, ShardId, Error]),
      Error
  end.

%% @doc Retrieve shard data
-spec get_shard(binary(), binary()) -> {ok, term()} | {error, term()}.
get_shard(VaultId, ShardId) ->
  logger:debug("Retrieving shard ~p:~p", [VaultId, ShardId]),
  vault_db:get_doc(shard_doc_id(VaultId, ShardId)).

%% @doc Retrieve all shards belonging to a vault using prefix range query
-spec get_all_shards_for_vault(binary()) -> {ok, list()} | {error, term()}.
get_all_shards_for_vault(VaultId) ->
  logger:debug("Retrieving all shards for vault ~p", [VaultId]),
  Prefix = <<(?SHARD_PREFIX)/binary, VaultId/binary, ":">>,
  vault_db:list_docs_by_prefix(Prefix, <<Prefix/binary, "~">>).

%% @doc Delete a single shard
-spec delete_shard(binary(), binary()) -> ok | {error, term()}.
delete_shard(VaultId, ShardId) ->
  logger:debug("Deleting shard ~p:~p", [VaultId, ShardId]),
  case vault_db:delete_doc(shard_doc_id(VaultId, ShardId)) of
    ok ->
      logger:debug("Shard ~p:~p deleted", [VaultId, ShardId]),
      ok;
    Error ->
      logger:error("Failed to delete shard ~p:~p: ~p", [VaultId, ShardId, Error]),
      Error
  end.

%% ===================================================================
%% Internal helpers
%% ===================================================================

shard_doc_id(VaultId, ShardId) ->
  <<(?SHARD_PREFIX)/binary, VaultId/binary, ":", ShardId/binary>>.
