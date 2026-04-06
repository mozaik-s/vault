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
  test_revoke_shard_access/1
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
    test_revoke_shard_access
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
  {ok, StoredShardId} = vault:store_shard(VaultPid, ShardId, EncryptedBlob),
  ShardId = StoredShardId,
  ok.

test_get_shard(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_2">>, <<"user_2">>),
  ShardId = <<"shard_b2">>,
  EncryptedBlob = <<"encrypted_data">>,
  vault:store_shard(VaultPid, ShardId, EncryptedBlob),
  {ok, RetrievedBlob} = vault:get_shard(VaultPid, ShardId),
  EncryptedBlob = RetrievedBlob,
  ok.

test_list_shards(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_3">>, <<"user_3">>),
  vault:store_shard(VaultPid, <<"shard_a">>, <<"data_a">>),
  vault:store_shard(VaultPid, <<"shard_b">>, <<"data_b">>),
  {ok, ShardIds} = vault:list_shards(VaultPid),
  2 = length(ShardIds),
  ok.

test_grant_shard_access(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_4">>, <<"user_4">>),
  vault:store_shard(VaultPid, <<"shard_c">>, <<"data_c">>),
  {ok, granted} = vault:grant_access(VaultPid, <<"user_5">>, view),
  ok.

test_revoke_shard_access(_Config) ->
  {ok, VaultPid} = vault:start_link(<<"vault_5">>, <<"user_5">>),
  vault:store_shard(VaultPid, <<"shard_d">>, <<"data_d">>),
  vault:grant_access(VaultPid, <<"user_6">>, upload),
  {ok, revoked} = vault:revoke_access(VaultPid, <<"user_6">>),
  ok.
