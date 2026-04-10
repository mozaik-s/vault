%%%-------------------------------------------------------------------
%% @doc Vault public API - Interface for calling vault from other applications
%% This module provides the public API for vault operations.
%% Internally delegates to vault_server gen_server.
%%%-------------------------------------------------------------------
-module(vault).

%% Public API
-export([
  start_link/2,
  grant_access/3,
  revoke_access/3,
  store_shard/4,
  get_shard/3,
  get_all_shards/2,
  get_vault_permissions/1
]).

%% ===================================================================
%% Public API
%% ===================================================================

%% @doc Start a vault process with the given vault_id and owner_id
-spec start_link(binary(), binary()) -> {ok, pid()} | {error, term()}.
start_link(VaultId, OwnerId) ->
  vault_server:start_link(VaultId, OwnerId).

%% @doc Grant user read access to vault — only the owner may call this
-spec grant_access(pid(), binary(), binary()) -> {ok, granted} | {error, term()}.
grant_access(VaultPid, UserId, CallerId) ->
  gen_server:call(VaultPid, {grant_access, CallerId, UserId}).

%% @doc Revoke user access to entire vault — only the owner may call this
-spec revoke_access(pid(), binary(), binary()) -> {ok, revoked} | {error, term()}.
revoke_access(VaultPid, UserId, CallerId) ->
  gen_server:call(VaultPid, {revoke_access, CallerId, UserId}).

%% @doc Store encrypted shard in vault
-spec store_shard(pid(), binary(), binary(), binary()) -> {ok, binary()} | {error, term()}.
store_shard(VaultPid, ShardId, EncryptedBlob, CallerId) ->
  gen_server:call(VaultPid, {store_shard, ShardId, EncryptedBlob, CallerId}).

%% @doc Get encrypted shard from vault
-spec get_shard(pid(), binary(), binary()) -> {ok, binary()} | {error, term()}.
get_shard(VaultPid, ShardId, CallerId) ->
  gen_server:call(VaultPid, {get_shard, ShardId, CallerId}).

%% @doc Get all shards for the vault as a map of #{ShardId => Blob}
-spec get_all_shards(pid(), binary()) -> {ok, map()} | {error, term()}.
get_all_shards(VaultPid, CallerId) ->
  gen_server:call(VaultPid, {get_all_shards, CallerId}).

%% @doc Get all vault-level permissions
-spec get_vault_permissions(pid()) -> {ok, map()} | {error, term()}.
get_vault_permissions(VaultPid) ->
  gen_server:call(VaultPid, get_vault_permissions).
