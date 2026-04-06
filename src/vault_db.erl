%%%-------------------------------------------------------------------
%% @doc Vault database interface - CouchDB operations
%% Library module (no gen_server) that abstracts CouchDB HTTP API via couchbeam
%%
%% Design:
%% - MVP uses single CouchDB database (mozaik_vault)
%% - Document prefixes: "vault:*" for vault documents, "shard:*" for shard data
%% - Phase 2+: Shards can migrate to separate DB or S3 for scalability
%%%-------------------------------------------------------------------
-module(vault_db).

%% API - stateless library functions
-export([
  store_vault/2,
  get_vault/1,
  update_vault/2,
  store_shard/3,
  get_shard/2,
  get_all_shards_for_vault/1,
  delete_shard/2,
  delete_vault/1
]).

-define(DB_URL, "http://localhost:5984/mozaik_vault").
-define(CONNECTION_TIMEOUT, 5000).
-define(VAULT_PREFIX, <<"vault:">>).
-define(SHARD_PREFIX, <<"shard:">>).

%% ===================================================================
%% Database Connection Management
%% ===================================================================

%% Get or establish CouchDB connection
%% Returns {ok, Connection} or {error, Reason}
get_connection() ->
  try
    case couchbeam:server_connection(?DB_URL, [{connection_timeout, ?CONNECTION_TIMEOUT}]) of
      {ok, Conn} -> {ok, Conn};
      Error ->
        logger:error("Failed to connect to CouchDB: ~p", [Error]),
        Error
    end
  catch
    Type:Reason ->
      logger:error("CouchDB connection exception: ~p:~p", [Type, Reason]),
      {error, {Type, Reason}}
  end.

%% ===================================================================
%% Vault Operations
%% ===================================================================

%% @doc Store vault state document to CouchDB
-spec store_vault(binary(), map()) -> {ok, map()} | {error, term()}.
store_vault(VaultId, VaultState) ->
  logger:debug("Storing vault ~p to CouchDB", [VaultId]),
  case get_connection() of
    {ok, Conn} -> store_vault_impl(Conn, VaultId, VaultState);
    Error -> Error
  end.

store_vault_impl(Conn, VaultId, VaultState) ->
  DocId = vault_doc_id(VaultId),
  Doc = VaultState#{<<"_id">> => DocId, <<"type">> => <<"vault">>},
  try
    case couchbeam:save_doc(Conn, Doc) of
      {ok, SavedDoc} ->
        logger:debug("Vault ~p saved successfully", [VaultId]),
        {ok, SavedDoc};
      Error ->
        logger:error("Failed to save vault ~p: ~p", [VaultId, Error]),
        {error, Error}
    end
  catch
    Type:Reason ->
      logger:error("Vault save exception ~p: ~p", [Type, Reason]),
      {error, {Type, Reason}}
  end.

%% @doc Retrieve vault state document from CouchDB
-spec get_vault(binary()) -> {ok, map()} | {error, term()}.
get_vault(VaultId) ->
  logger:debug("Retrieving vault ~p from CouchDB", [VaultId]),
  case get_connection() of
    {ok, Conn} -> get_vault_impl(Conn, VaultId);
    Error -> Error
  end.

get_vault_impl(Conn, VaultId) ->
  DocId = vault_doc_id(VaultId),
  try
    case couchbeam:open_doc(Conn, DocId) of
      {ok, Doc} ->
        logger:debug("Vault ~p retrieved successfully", [VaultId]),
        {ok, Doc};
      {not_found, _} ->
        logger:info("Vault ~p not found in CouchDB", [VaultId]),
        {error, not_found};
      Error ->
        logger:error("Failed to retrieve vault ~p: ~p", [VaultId, Error]),
        {error, Error}
    end
  catch
    Type:Reason ->
      logger:error("Vault retrieval exception ~p: ~p", [Type, Reason]),
      {error, {Type, Reason}}
  end.

%% @doc Update vault state (fetch, merge, save)
-spec update_vault(binary(), map()) -> {ok, map()} | {error, term()}.
update_vault(VaultId, Updates) ->
  logger:debug("Updating vault ~p in CouchDB", [VaultId]),
  case get_vault(VaultId) of
    {ok, CurrentDoc} ->
      UpdatedDoc = maps:merge(CurrentDoc, Updates),
      store_vault(VaultId, UpdatedDoc);
    Error ->
      {error, Error}
  end.

%% ===================================================================
%% Shard Operations
%% ===================================================================

%% @doc Store shard document to CouchDB
-spec store_shard(binary(), binary(), map()) -> {ok, map()} | {error, term()}.
store_shard(VaultId, ShardId, ShardData) ->
  logger:debug("Storing shard ~p:~p to CouchDB", [VaultId, ShardId]),
  case get_connection() of
    {ok, Conn} -> store_shard_impl(Conn, VaultId, ShardId, ShardData);
    Error -> Error
  end.

store_shard_impl(Conn, VaultId, ShardId, ShardData) ->
  DocId = shard_doc_id(VaultId, ShardId),
  Doc = ShardData#{<<"_id">> => DocId, <<"type">> => <<"shard">>, <<"vault_id">> => VaultId},
  try
    case couchbeam:save_doc(Conn, Doc) of
      {ok, SavedDoc} ->
        logger:debug("Shard ~p:~p saved successfully", [VaultId, ShardId]),
        {ok, SavedDoc};
      Error ->
        logger:error("Failed to save shard ~p:~p: ~p", [VaultId, ShardId, Error]),
        {error, Error}
    end
  catch
    Type:Reason ->
      logger:error("Shard save exception ~p: ~p", [Type, Reason]),
      {error, {Type, Reason}}
  end.

%% @doc Retrieve shard document from CouchDB
-spec get_shard(binary(), binary()) -> {ok, map()} | {error, term()}.
get_shard(VaultId, ShardId) ->
  logger:debug("Retrieving shard ~p:~p from CouchDB", [VaultId, ShardId]),
  case get_connection() of
    {ok, Conn} -> get_shard_impl(Conn, VaultId, ShardId);
    Error -> Error
  end.

get_shard_impl(Conn, VaultId, ShardId) ->
  DocId = shard_doc_id(VaultId, ShardId),
  try
    case couchbeam:open_doc(Conn, DocId) of
      {ok, Doc} ->
        logger:debug("Shard ~p:~p retrieved successfully", [VaultId, ShardId]),
        {ok, Doc};
      {not_found, _} ->
        logger:info("Shard ~p:~p not found in CouchDB", [VaultId, ShardId]),
        {error, not_found};
      Error ->
        logger:error("Failed to retrieve shard ~p:~p: ~p", [VaultId, ShardId, Error]),
        {error, Error}
    end
  catch
    Type:Reason ->
      logger:error("Shard retrieval exception ~p: ~p", [Type, Reason]),
      {error, {Type, Reason}}
  end.

%% @doc Get all shards for a vault using prefix query
-spec get_all_shards_for_vault(binary()) -> {ok, list()} | {error, term()}.
get_all_shards_for_vault(VaultId) ->
  logger:debug("Retrieving all shards for vault ~p", [VaultId]),
  case get_connection() of
    {ok, Conn} -> get_all_shards_impl(Conn, VaultId);
    Error -> Error
  end.

get_all_shards_impl(Conn, VaultId) ->
  Prefix = <<(?SHARD_PREFIX)/binary, VaultId/binary, ":">>,
  StartKey = Prefix,
  EndKey = <<Prefix/binary, "~">>,
  Options = [{startkey, StartKey}, {endkey, EndKey}, {include_docs, true}],
  try
    case couchbeam:view(Conn, "_all_docs", [], Options) of
      {ok, Rows} ->
        Docs = [Doc || {Doc} <- [Row || {Row} <- Rows, is_tuple(Row)]],
        logger:debug("Found ~p shards for vault ~p", [length(Docs), VaultId]),
        {ok, Docs};
      Error ->
        logger:error("Failed to list shards for vault ~p: ~p", [VaultId, Error]),
        {error, Error}
    end
  catch
    Type:Reason ->
      logger:error("Shard list exception ~p: ~p", [Type, Reason]),
      {error, {Type, Reason}}
  end.

%% ===================================================================
%% Deletion Operations
%% ===================================================================

%% @doc Delete a shard document
-spec delete_shard(binary(), binary()) -> ok | {error, term()}.
delete_shard(VaultId, ShardId) ->
  logger:debug("Deleting shard ~p:~p from CouchDB", [VaultId, ShardId]),
  case get_shard(VaultId, ShardId) of
    {ok, Doc} -> delete_shard_doc(Doc, VaultId, ShardId);
    Error -> Error
  end.

delete_shard_doc(Doc, VaultId, ShardId) ->
  case get_connection() of
    {ok, Conn} -> delete_shard_impl(Conn, Doc, VaultId, ShardId);
    Error -> Error
  end.

delete_shard_impl(Conn, Doc, VaultId, ShardId) ->
  try
    case couchbeam:delete_doc(Conn, Doc) of
      {ok, _} ->
        logger:debug("Shard ~p:~p deleted successfully", [VaultId, ShardId]),
        ok;
      Error ->
        logger:error("Failed to delete shard ~p:~p: ~p", [VaultId, ShardId, Error]),
        {error, Error}
    end
  catch
    Type:Reason ->
      logger:error("Shard delete exception ~p: ~p", [Type, Reason]),
      {error, {Type, Reason}}
  end.

%% @doc Delete entire vault and all its shards
-spec delete_vault(binary()) -> ok | {error, term()}.
delete_vault(VaultId) ->
  logger:debug("Deleting vault ~p and all shards from CouchDB", [VaultId]),
  case get_vault(VaultId) of
    {ok, VaultDoc} -> delete_vault_impl(VaultDoc, VaultId);
    Error -> Error
  end.

delete_vault_impl(VaultDoc, VaultId) ->
  case delete_all_shards_for_vault(VaultId) of
    ok -> delete_vault_doc(VaultDoc, VaultId);
    Error -> Error
  end.

delete_vault_doc(VaultDoc, VaultId) ->
  case get_connection() of
    {ok, Conn} -> delete_vault_final(Conn, VaultDoc, VaultId);
    Error -> Error
  end.

delete_vault_final(Conn, VaultDoc, VaultId) ->
  try
    case couchbeam:delete_doc(Conn, VaultDoc) of
      {ok, _} ->
        logger:debug("Vault ~p and all shards deleted successfully", [VaultId]),
        ok;
      Error ->
        logger:error("Failed to delete vault ~p: ~p", [VaultId, Error]),
        {error, Error}
    end
  catch
    Type:Reason ->
      logger:error("Vault delete exception ~p: ~p", [Type, Reason]),
      {error, {Type, Reason}}
  end.

%% ===================================================================
%% Helper Functions
%% ===================================================================

%% Generate vault document ID: "vault:VaultId"
vault_doc_id(VaultId) ->
  <<(?VAULT_PREFIX)/binary, VaultId/binary>>.

%% Generate shard document ID: "shard:VaultId:ShardId"
shard_doc_id(VaultId, ShardId) ->
  <<(?SHARD_PREFIX)/binary, VaultId/binary, ":", ShardId/binary>>.

%% Delete all shards for a vault (internal helper)
delete_all_shards_for_vault(VaultId) ->
  case get_all_shards_for_vault(VaultId) of
    {ok, Docs} -> delete_docs_batch(Docs);
    Error -> Error
  end.

%% Delete a batch of documents
delete_docs_batch(Docs) ->
  case get_connection() of
    {ok, Conn} -> delete_docs_batch_impl(Conn, Docs);
    Error -> Error
  end.

delete_docs_batch_impl(Conn, Docs) ->
  try
    Results = [doc_delete_result(Conn, Doc) || Doc <- Docs],
    case lists:all(fun is_ok_result/1, Results) of
      true -> ok;
      false -> {error, batch_delete_failed}
    end
  catch
    Type:Reason ->
      logger:error("Batch delete failed: ~p:~p", [Type, Reason]),
      {error, {Type, Reason}}
  end.

%% Safely delete a document
doc_delete_result(Conn, Doc) ->
  try
    couchbeam:delete_doc(Conn, Doc)
  catch
    Type:Reason ->
      {error, {Type, Reason}}
  end.

%% Check if result is ok
is_ok_result({ok, _}) -> true;
is_ok_result(_) -> false.
