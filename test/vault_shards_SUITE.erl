%%%-------------------------------------------------------------------
%% @doc Common Test suite for vault_shards module (integration tests)
%%%-------------------------------------------------------------------
-module(vault_shards_SUITE).

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
        test_get_all_shards_for_vault,
        test_delete_shard,
        test_integrity_hash_stored
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
    VaultId = <<"vault_shards_1">>,
    ShardId = <<"shard_1">>,
    Blob = <<"encrypted_data_abc">>,
    {ok, _} = vault_shards:store_shard(VaultId, ShardId, #{<<"data">> => Blob}),
    {ok, Doc} = vault_shards:get_shard(VaultId, ShardId),
    #{<<"data">> := Blob} = vault_db:ejson_to_map(Doc),
    ok.

test_get_nonexistent_returns_not_found(_Config) ->
    {error, not_found} = vault_shards:get_shard(<<"no_vault">>, <<"no_shard">>),
    ok.

test_get_all_shards_for_vault(_Config) ->
    VaultId = <<"vault_shards_all_3">>,
    {ok, _} = vault_shards:store_shard(VaultId, <<"s1">>, #{<<"data">> => <<"d1">>}),
    {ok, _} = vault_shards:store_shard(VaultId, <<"s2">>, #{<<"data">> => <<"d2">>}),
    {ok, _} = vault_shards:store_shard(VaultId, <<"s3">>, #{<<"data">> => <<"d3">>}),
    {ok, Docs} = vault_shards:get_all_shards_for_vault(VaultId),
    3 = length(Docs),
    ok.

test_delete_shard(_Config) ->
    VaultId = <<"vault_shards_del_4">>,
    ShardId = <<"shard_del">>,
    {ok, _} = vault_shards:store_shard(VaultId, ShardId, #{<<"data">> => <<"temp">>}),
    ok = vault_shards:delete_shard(VaultId, ShardId),
    {error, not_found} = vault_shards:get_shard(VaultId, ShardId),
    ok.

test_integrity_hash_stored(_Config) ->
    VaultId = <<"vault_shards_hash_5">>,
    ShardId = <<"shard_hash">>,
    Blob = <<"verify_hash_data">>,
    {ok, _} = vault_shards:store_shard(VaultId, ShardId, #{<<"data">> => Blob}),
    DocId = <<"shard:", VaultId/binary, ":", ShardId/binary>>,
    {ok, Doc} = vault_db:get_doc(DocId),
    #{<<"hash">> := Hash} = vault_db:ejson_to_map(Doc),
    true = is_binary(Hash),
    true = byte_size(Hash) =:= 64,
    ok.
