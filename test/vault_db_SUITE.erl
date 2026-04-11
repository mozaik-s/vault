%%%-------------------------------------------------------------------
%% @doc Common Test suite for vault_db module (CouchDB integration tests)
%%%-------------------------------------------------------------------
-module(vault_db_SUITE).

-include_lib("common_test/include/ct.hrl").

-compile(export_all).
-compile(nowarn_export_all).

%% ===================================================================
%% Common Test Callbacks
%% ===================================================================

suite() -> [{timetrap, {seconds, 30}}].

all() ->
    [
        test_store_and_get_roundtrip,
        test_get_nonexistent_returns_not_found,
        test_delete_removes_document,
        test_store_replaces_existing,
        test_list_docs_by_prefix,
        test_store_and_get_vault,
        test_update_vault_merges,
        test_delete_vault,
        test_ejson_to_map
    ].

init_per_suite(Config) ->
    case application:ensure_all_started(vault) of
        {ok, _} -> Config;
        {error, _} -> {skip, "vault application failed to start"}
    end.

end_per_suite(_Config) -> ok.

init_per_testcase(_TestCase, Config) -> Config.

end_per_testcase(_TestCase, _Config) -> ok.

%% ===================================================================
%% Test Cases
%% ===================================================================

test_store_and_get_roundtrip(_Config) ->
    DocId = <<"test_db_roundtrip_1">>,
    Data = #{<<"key">> => <<"value">>, <<"num">> => 42},
    {ok, _} = vault_db:store_doc(DocId, Data),
    {ok, Doc} = vault_db:get_doc(DocId),
    #{<<"key">> := <<"value">>, <<"num">> := 42} = vault_db:ejson_to_map(Doc),
    ok.

test_get_nonexistent_returns_not_found(_Config) ->
    {error, not_found} = vault_db:get_doc(<<"nonexistent_doc_xyz">>),
    ok.

test_delete_removes_document(_Config) ->
    DocId = <<"test_db_delete_2">>,
    {ok, _} = vault_db:store_doc(DocId, #{<<"data">> => <<"to_delete">>}),
    {ok, _} = vault_db:get_doc(DocId),
    ok = vault_db:delete_doc(DocId),
    {error, not_found} = vault_db:get_doc(DocId),
    ok.

test_store_replaces_existing(_Config) ->
    DocId = <<"test_db_replace_3">>,
    {ok, _} = vault_db:store_doc(DocId, #{<<"version">> => 1}),
    {ok, _} = vault_db:store_doc(DocId, #{<<"version">> => 2}),
    {ok, Doc} = vault_db:get_doc(DocId),
    #{<<"version">> := 2} = vault_db:ejson_to_map(Doc),
    ok.

test_list_docs_by_prefix(_Config) ->
    Prefix = <<"test_prefix_4:">>,
    {ok, _} = vault_db:store_doc(<<Prefix/binary, "a">>, #{<<"id">> => <<"a">>}),
    {ok, _} = vault_db:store_doc(<<Prefix/binary, "b">>, #{<<"id">> => <<"b">>}),
    {ok, _} = vault_db:store_doc(<<Prefix/binary, "c">>, #{<<"id">> => <<"c">>}),
    {ok, Docs} = vault_db:list_docs_by_prefix(Prefix, <<Prefix/binary, "~">>),
    3 = length(Docs),
    ok.

test_store_and_get_vault(_Config) ->
    VaultId = <<"test_vault_5">>,
    State = #{<<"owner_id">> => <<"owner_5">>, <<"permissions">> => #{}},
    {ok, _} = vault_db:store_vault(VaultId, State),
    {ok, Doc} = vault_db:get_vault(VaultId),
    #{<<"owner_id">> := <<"owner_5">>} = vault_db:ejson_to_map(Doc),
    ok.

test_update_vault_merges(_Config) ->
    VaultId = <<"test_vault_merge_6">>,
    {ok, _} = vault_db:store_vault(VaultId, #{<<"field_a">> => 1}),
    {ok, _} = vault_db:update_vault(VaultId, #{<<"field_b">> => 2}),
    {ok, Doc} = vault_db:get_vault(VaultId),
    Map = vault_db:ejson_to_map(Doc),
    #{<<"field_a">> := 1, <<"field_b">> := 2} = Map,
    ok.

test_delete_vault(_Config) ->
    VaultId = <<"test_vault_del_7">>,
    {ok, _} = vault_db:store_vault(VaultId, #{<<"data">> => <<"temp">>}),
    ok = vault_db:delete_vault(VaultId),
    {error, not_found} = vault_db:get_vault(VaultId),
    ok.

test_ejson_to_map(_Config) ->
    Ejson = {[{<<"key">>, <<"val">>}, {<<"nested">>, {[{<<"a">>, 1}]}}]},
    #{<<"key">> := <<"val">>, <<"nested">> := #{<<"a">> := 1}} = vault_db:ejson_to_map(Ejson),
    ok.
