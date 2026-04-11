%%%-------------------------------------------------------------------
%% Common Test suite for Vault gen_server
%%%-------------------------------------------------------------------
-module(vault_SUITE).

-include_lib("common_test/include/ct.hrl").

-compile(export_all).
-compile(nowarn_export_all).

%% ===================================================================
%% Suite callbacks
%% ===================================================================

all() ->
    [
        test_vault_start_link,
        test_store_shard,
        test_get_shard,
        test_get_all_shards,
        test_grant_shard_access,
        test_revoke_shard_access,
        test_unauthorized_get_shard,
        test_unauthorized_store_shard,
        test_unauthorized_grant_access,
        test_revoke_removes_access,
        test_shard_survives_restart,
        test_tampered_shard_detected
    ].

init_per_suite(Config) ->
    case application:ensure_started(vault) of
        ok -> ok;
        {error, _} -> ok
    end,
    Config.

end_per_suite(_Config) ->
    ok.

init_per_testcase(_Case, Config) ->
    Config.

end_per_testcase(_Case, _Config) ->
    ok.

%% ===================================================================
%% Test cases
%% ===================================================================

test_vault_start_link(_Config) ->
    VaultId = <<"test_vault_123">>,
    OwnerId = <<"user_456">>,
    {ok, Pid} = vault:start_link(VaultId, OwnerId),
    true = is_pid(Pid),
    ok.

test_store_shard(_Config) ->
    {ok, VaultPid} = vault:start_link(<<"vault_1">>, <<"user_1">>),
    ShardId = <<"shard_a1">>,
    EncryptedBlob = <<"encrypted_data">>,
    {ok, StoredShardId} = vault:store_shard(VaultPid, ShardId, EncryptedBlob, <<"user_1">>),
    ShardId = StoredShardId,
    ok.

test_get_shard(_Config) ->
    {ok, VaultPid} = vault:start_link(<<"vault_2">>, <<"user_2">>),
    ShardId = <<"shard_b2">>,
    EncryptedBlob = <<"encrypted_data">>,
    vault:store_shard(VaultPid, ShardId, EncryptedBlob, <<"user_2">>),
    {ok, RetrievedBlob} = vault:get_shard(VaultPid, ShardId, <<"user_2">>),
    EncryptedBlob = RetrievedBlob,
    ok.

test_get_all_shards(_Config) ->
    {ok, VaultPid} = vault:start_link(<<"vault_3">>, <<"user_3">>),
    vault:store_shard(VaultPid, <<"shard_a">>, <<"data_a">>, <<"user_3">>),
    vault:store_shard(VaultPid, <<"shard_b">>, <<"data_b">>, <<"user_3">>),
    {ok, Shards} = vault:get_all_shards(VaultPid, <<"user_3">>),
    2 = map_size(Shards),
    <<"data_a">> = maps:get(<<"shard_a">>, Shards),
    <<"data_b">> = maps:get(<<"shard_b">>, Shards),
    ok.

test_grant_shard_access(_Config) ->
    {ok, VaultPid} = vault:start_link(<<"vault_4">>, <<"user_4">>),
    vault:store_shard(VaultPid, <<"shard_c">>, <<"data_c">>, <<"user_4">>),
    {ok, granted} = vault:grant_access(VaultPid, <<"user_5">>, <<"user_4">>),
    {ok, Perms} = vault:get_vault_permissions(VaultPid),
    <<"read">> = maps:get(crypto:hash(sha256, <<"user_5">>), Perms),
    ok.

test_revoke_shard_access(_Config) ->
    {ok, VaultPid} = vault:start_link(<<"vault_5">>, <<"user_5">>),
    vault:store_shard(VaultPid, <<"shard_d">>, <<"data_d">>, <<"user_5">>),
    vault:grant_access(VaultPid, <<"user_6">>, <<"user_5">>),
    {ok, revoked} = vault:revoke_access(VaultPid, <<"user_6">>, <<"user_5">>),
    {ok, Perms} = vault:get_vault_permissions(VaultPid),
    false = maps:is_key(crypto:hash(sha256, <<"user_6">>), Perms),
    ok.

test_unauthorized_get_shard(_Config) ->
    {ok, VaultPid} = vault:start_link(<<"vault_6">>, <<"alice">>),
    vault:store_shard(VaultPid, <<"shard_e">>, <<"secret">>, <<"alice">>),
    {error, unauthorized} = vault:get_shard(VaultPid, <<"shard_e">>, <<"charlie">>),
    ok.

test_unauthorized_store_shard(_Config) ->
    {ok, VaultPid} = vault:start_link(<<"vault_7">>, <<"alice">>),
    vault:grant_access(VaultPid, <<"bob">>, <<"alice">>),
    {error, unauthorized} = vault:store_shard(VaultPid, <<"s2">>, <<"data">>, <<"bob">>),
    ok.

test_unauthorized_grant_access(_Config) ->
    {ok, VaultPid} = vault:start_link(<<"vault_9">>, <<"alice">>),
    {error, unauthorized} = vault:grant_access(VaultPid, <<"eve">>, <<"bob">>),
    ok.

test_revoke_removes_access(_Config) ->
    {ok, VaultPid} = vault:start_link(<<"vault_8">>, <<"alice">>),
    vault:grant_access(VaultPid, <<"dave">>, <<"alice">>),
    vault:store_shard(VaultPid, <<"shard_f">>, <<"payload">>, <<"alice">>),
    {ok, <<"payload">>} = vault:get_shard(VaultPid, <<"shard_f">>, <<"dave">>),
    vault:revoke_access(VaultPid, <<"dave">>, <<"alice">>),
    {error, unauthorized} = vault:get_shard(VaultPid, <<"shard_f">>, <<"dave">>),
    ok.

test_shard_survives_restart(_Config) ->
    VaultId = <<"vault_persist_9">>,
    OwnerId = <<"user_persist_9">>,
    ShardId = <<"shard_persist_9">>,
    Blob = <<"persistent_data_xyz">>,
    {ok, Pid1} = vault:start_link(VaultId, OwnerId),
    {ok, ShardId} = vault:store_shard(Pid1, ShardId, Blob, OwnerId),
    ok = gen_server:stop(Pid1),
    {ok, Pid2} = vault:start_link(VaultId, OwnerId),
    {ok, Blob} = vault:get_shard(Pid2, ShardId, OwnerId),
    ok.

test_tampered_shard_detected(_Config) ->
    VaultId = <<"vault_tamper_10">>,
    OwnerId = <<"user_tamper_10">>,
    ShardId = <<"shard_tamper_10">>,
    Blob = <<"original_data">>,
    {ok, Pid} = vault:start_link(VaultId, OwnerId),
    {ok, ShardId} = vault:store_shard(Pid, ShardId, Blob, OwnerId),
    %% Tamper the shard directly in CouchDB
    DocId = <<"shard:", VaultId/binary, ":", ShardId/binary>>,
    {ok, Doc} = vault_db:get_doc(DocId),
    TamperedData = #{<<"data">> => <<"corrupted">>},
    {ok, _} = vault_db:store_doc(DocId, TamperedData),
    %% Ignore the raw Doc variable to avoid unused warning
    _ = Doc,
    %% Retrieve should fail integrity check
    {error, integrity_check_failed} = vault:get_shard(Pid, ShardId, OwnerId),
    ok.
