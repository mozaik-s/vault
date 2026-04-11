%%%-------------------------------------------------------------------
%% @doc Generic CouchDB adapter
%% Low-level document operations for the mozaik_vault database.
%% Business logic (shard prefixes, vault prefixes) lives in higher modules.
%%%-------------------------------------------------------------------
-module(vault_db).

-export([
    store_doc/2,
    get_doc/1,
    delete_doc/1,
    list_docs_by_prefix/2,
    store_vault/2,
    get_vault/1,
    update_vault/2,
    delete_vault/1,
    ejson_to_map/1
]).

-define(DEFAULT_SERVER_URL, "http://localhost:5984").
-define(DEFAULT_DB_NAME, <<"mozaik_vault">>).
-define(DEFAULT_CONNECTION_TIMEOUT, 5000).
-define(VAULT_PREFIX, <<"vault:">>).

%% ===================================================================
%% Generic DB Operations
%% ===================================================================

%% @doc Store a document by ID (creates or replaces)
-spec store_doc(binary(), map()) -> {ok, term()} | {error, term()}.
store_doc(DocId, Data) ->
    case get_connection() of
        {ok, Conn} -> store_doc_impl(Conn, DocId, Data);
        Error -> Error
    end.

%% @doc Retrieve a document by ID
-spec get_doc(binary()) -> {ok, term()} | {error, term()}.
get_doc(DocId) ->
    case get_connection() of
        {ok, Conn} -> get_doc_impl(Conn, DocId);
        Error -> Error
    end.

%% @doc Delete a document by ID
-spec delete_doc(binary()) -> ok | {error, term()}.
delete_doc(DocId) ->
    case get_connection() of
        {ok, Conn} ->
            case get_doc_impl(Conn, DocId) of
                {ok, Doc} -> delete_doc_impl(Conn, Doc);
                {error, _} = Err -> Err
            end;
        Error ->
            Error
    end.

%% @doc List all documents whose IDs fall within [StartKey, EndKey)
-spec list_docs_by_prefix(binary(), binary()) -> {ok, list()} | {error, term()}.
list_docs_by_prefix(StartKey, EndKey) ->
    case get_connection() of
        {ok, Conn} -> list_docs_impl(Conn, StartKey, EndKey);
        Error -> Error
    end.

%% ===================================================================
%% Vault Document Convenience Functions
%% ===================================================================

%% @doc Persist vault state to CouchDB
-spec store_vault(binary(), map()) -> {ok, term()} | {error, term()}.
store_vault(VaultId, VaultState) ->
    logger:debug("Storing vault ~p to CouchDB", [VaultId]),
    store_doc(vault_doc_id(VaultId), VaultState#{<<"type">> => <<"vault">>}).

%% @doc Retrieve vault state from CouchDB
-spec get_vault(binary()) -> {ok, term()} | {error, term()}.
get_vault(VaultId) ->
    logger:debug("Retrieving vault ~p from CouchDB", [VaultId]),
    get_doc(vault_doc_id(VaultId)).

%% @doc Update vault state (fetch, merge, save)
-spec update_vault(binary(), map()) -> {ok, term()} | {error, term()}.
update_vault(VaultId, Updates) ->
    logger:debug("Updating vault ~p in CouchDB", [VaultId]),
    case get_vault(VaultId) of
        {ok, CurrentDoc} ->
            store_vault(VaultId, maps:merge(CurrentDoc, Updates));
        Error ->
            Error
    end.

%% @doc Delete a vault document
-spec delete_vault(binary()) -> ok | {error, term()}.
delete_vault(VaultId) ->
    logger:debug("Deleting vault ~p from CouchDB", [VaultId]),
    delete_doc(vault_doc_id(VaultId)).

%% ===================================================================
%% Internal Implementation
%% ===================================================================

-spec get_connection() -> {ok, term()} | {error, term()}.
get_connection() ->
    try
        Server = couchbeam:server_connection(server_url(), [
            {connection_timeout, connection_timeout()}
        ]),
        couchbeam:open_db(Server, db_name())
    catch
        Type:Reason ->
            logger:error("CouchDB connection exception: ~p:~p", [Type, Reason]),
            {error, {Type, Reason}}
    end.

-spec server_url() -> string().
server_url() ->
    case os:getenv("VAULT_DB_URL") of
        false -> ?DEFAULT_SERVER_URL;
        Url -> Url
    end.

-spec db_name() -> binary().
db_name() ->
    case os:getenv("VAULT_DB_NAME") of
        false -> ?DEFAULT_DB_NAME;
        Name -> list_to_binary(Name)
    end.

-spec connection_timeout() -> pos_integer().
connection_timeout() ->
    case os:getenv("VAULT_DB_TIMEOUT") of
        false ->
            ?DEFAULT_CONNECTION_TIMEOUT;
        Val ->
            try list_to_integer(Val) of
                N when N > 0 -> N;
                _ -> ?DEFAULT_CONNECTION_TIMEOUT
            catch
                _:_ -> ?DEFAULT_CONNECTION_TIMEOUT
            end
    end.

store_doc_impl(Conn, DocId, Data) ->
    Doc = map_to_ejson(Data#{<<"_id">> => DocId}),
    try
        case couchbeam:save_doc(Conn, Doc) of
            {ok, Saved} -> {ok, Saved};
            Error -> {error, Error}
        end
    catch
        Type:Reason ->
            logger:error("save_doc exception for ~p: ~p:~p", [DocId, Type, Reason]),
            {error, {Type, Reason}}
    end.

get_doc_impl(Conn, DocId) ->
    try
        case couchbeam:open_doc(Conn, DocId) of
            {ok, Doc} -> {ok, Doc};
            {not_found, _} -> {error, not_found};
            Error -> {error, Error}
        end
    catch
        Type:Reason ->
            logger:error("open_doc exception for ~p: ~p:~p", [DocId, Type, Reason]),
            {error, {Type, Reason}}
    end.

delete_doc_impl(Conn, Doc) ->
    try
        case couchbeam:delete_doc(Conn, Doc) of
            {ok, _} -> ok;
            Error -> {error, Error}
        end
    catch
        Type:Reason ->
            logger:error("delete_doc exception: ~p:~p", [Type, Reason]),
            {error, {Type, Reason}}
    end.

list_docs_impl(Conn, StartKey, EndKey) ->
    Options = [{start_key, StartKey}, {end_key, EndKey}, include_docs],
    try
        case couchbeam_view:fetch(Conn, all_docs, Options) of
            {ok, Rows} ->
                Docs = [proplists:get_value(<<"doc">>, Row) || {Row} <- Rows],
                {ok, Docs};
            Error ->
                {error, Error}
        end
    catch
        Type:Reason ->
            logger:error("list_docs exception ~p-~p: ~p:~p", [StartKey, EndKey, Type, Reason]),
            {error, {Type, Reason}}
    end.

vault_doc_id(VaultId) ->
    <<(?VAULT_PREFIX)/binary, VaultId/binary>>.

%% Convert Erlang map/list to couchbeam ejson format ({[{K,V}]})
map_to_ejson(Map) when is_map(Map) ->
    {[{key_to_binary(K), map_to_ejson(V)} || {K, V} <- maps:to_list(Map)]};
map_to_ejson(List) when is_list(List) ->
    [map_to_ejson(Item) || Item <- List];
map_to_ejson(Value) ->
    Value.

key_to_binary(K) when is_atom(K) -> atom_to_binary(K, utf8);
key_to_binary(K) when is_binary(K) -> K.

%% Convert couchbeam ejson format ({[{K,V}]}) back to Erlang map
-spec ejson_to_map(term()) -> map() | list() | term().
ejson_to_map({Props}) when is_list(Props) ->
    maps:from_list([{K, ejson_to_map(V)} || {K, V} <- Props]);
ejson_to_map(List) when is_list(List) ->
    [ejson_to_map(Item) || Item <- List];
ejson_to_map(Value) ->
    Value.
