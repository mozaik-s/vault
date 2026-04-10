%%%-------------------------------------------------------------------
%% Common Test suite for Vault gen_server
%%%-------------------------------------------------------------------
-module(vault_SUITE).

-include_lib("common_test/include/ct.hrl").

%% Suite exports
-export([
  all/0,
  init_per_suite/1,
  end_per_suite/1,
  init_per_testcase/2,
  end_per_testcase/2
]).

%% Test cases
-export([
  test_vault_start_link/1,
  test_store_shard/1,
  test_get_shard/1,
  test_list_shards/1,
  test_grant_shard_access/1,
  test_revoke_shard_access/1,
  test_unauthorized_get_shard/1,
  test_unauthorized_store_shard/1,
  test_revoke_removes_access/1,
  test_shard_survives_restart/1
]).

%% ===================================================================
%% Type specs
%% ===================================================================

-spec all() -> [atom()].
-spec init_per_suite(list()) -> list().
-spec end_per_suite(list()) -> ok.
-spec init_per_testcase(atom(), list()) -> list().
-spec end_per_testcase(atom(), list()) -> ok.
-spec test_vault_start_link(list()) -> ok.
-spec test_store_shard(list()) -> ok.
-spec test_get_shard(list()) -> ok.
-spec test_list_shards(list()) -> ok.
-spec test_grant_shard_access(list()) -> ok.
-spec test_revoke_shard_access(list()) -> ok.
-spec test_unauthorized_get_shard(list()) -> ok.
-spec test_unauthorized_store_shard(list()) -> ok.
-spec test_revoke_removes_access(list()) -> ok.
-spec test_shard_survives_restart(list()) -> ok.

%% ===================================================================
%% Suite callbacks
%% ===================================================================

all() ->
  [
    test_vault_start_link,
    test_store_shard,
    test_get_shard,
    test_list_shards,
    test_grant_shard_access,
    test_revoke_shard_access,
    test_unauthorized_get_shard,
    test_unauthorized_store_shard,
    test_revoke_removes_access,
    test_shard_survives_restart
  ].

init_per_suite(Config) ->
  % Try to start application, but don't fail if not available
  case application:ensure_started(vault) of
    ok -> ok;
    {error, _} -> ok
  end,
  Config.

end_per_suite(_Config) ->
  ok.

init_per_testcase(test_shard_survives_restart, Config) ->
  case is_couchdb_available() of
    true  -> Config;
    false -> {skip, "CouchDB not available"}
  end;
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

test_list_shards(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_3">>, <<"user_3">>),
  vault:store_shard(VaultPid, <<"shard_a">>, <<"data_a">>, <<"user_3">>),
  vault:store_shard(VaultPid, <<"shard_b">>, <<"data_b">>, <<"user_3">>),
  {ok, ShardIds} = vault:list_shards(VaultPid),
  2 = length(ShardIds),
  ok.

test_grant_shard_access(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_4">>, <<"user_4">>),
  vault:store_shard(VaultPid, <<"shard_c">>, <<"data_c">>, <<"user_4">>),
  {ok, granted} = vault:grant_access(VaultPid, <<"user_5">>),
  {ok, Perms} = vault:get_vault_permissions(VaultPid),
  <<"read">> = maps:get(<<"user_5">>, Perms),
  ok.

test_revoke_shard_access(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_5">>, <<"user_5">>),
  vault:store_shard(VaultPid, <<"shard_d">>, <<"data_d">>, <<"user_5">>),
  vault:grant_access(VaultPid, <<"user_6">>),
  {ok, revoked} = vault:revoke_access(VaultPid, <<"user_6">>),
  {ok, Perms} = vault:get_vault_permissions(VaultPid),
  false = maps:is_key(<<"user_6">>, Perms),
  ok.

test_unauthorized_get_shard(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_6">>, <<"alice">>),
  vault:store_shard(VaultPid, <<"shard_e">>, <<"secret">>, <<"alice">>),
  {error, unauthorized} = vault:get_shard(VaultPid, <<"shard_e">>, <<"charlie">>),
  ok.

test_unauthorized_store_shard(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_7">>, <<"alice">>),
  vault:grant_access(VaultPid, <<"bob">>),
  {error, unauthorized} = vault:store_shard(VaultPid, <<"s2">>, <<"data">>, <<"bob">>),
  ok.

test_revoke_removes_access(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_8">>, <<"alice">>),
  vault:grant_access(VaultPid, <<"dave">>),
  vault:store_shard(VaultPid, <<"shard_f">>, <<"payload">>, <<"alice">>),
  {ok, <<"payload">>} = vault:get_shard(VaultPid, <<"shard_f">>, <<"dave">>),
  vault:revoke_access(VaultPid, <<"dave">>),
  {error, unauthorized} = vault:get_shard(VaultPid, <<"shard_f">>, <<"dave">>),
  ok.

test_shard_survives_restart(_Config) ->
  VaultId  = <<"vault_persist_9">>,
  OwnerId  = <<"user_persist_9">>,
  ShardId  = <<"shard_persist_9">>,
  Blob     = <<"persistent_data_xyz">>,
  {ok, Pid1} = vault:start_link(VaultId, OwnerId),
  {ok, ShardId} = vault:store_shard(Pid1, ShardId, Blob, OwnerId),
  ok = gen_server:stop(Pid1),
  {ok, Pid2} = vault:start_link(VaultId, OwnerId),
  {ok, Blob} = vault:get_shard(Pid2, ShardId, OwnerId),
  ok.

%% ===================================================================
%% Internal helpers
%% ===================================================================

is_couchdb_available() ->
  case gen_tcp:connect("localhost", 5984, [], 1000) of
    {ok, Sock} -> gen_tcp:close(Sock), true;
    _          -> false
  end.
