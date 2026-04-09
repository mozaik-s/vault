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
  revoke_access/2,
  store_shard/4,
  get_shard/3,
  list_shards/1,
  get_vault_permissions/1
]).

%% ===================================================================
%% Public API
%% ===================================================================

%% @doc Start a vault process with the given vault_id and owner_id
-spec start_link(binary(), binary()) -> {ok, pid()} | {error, term()}.
start_link(VaultId, OwnerId) ->
  vault_server:start_link(VaultId, OwnerId).

%% @doc Grant user access to entire vault
-spec grant_access(pid(), binary(), atom()) -> {ok, granted} | {error, term()}.
grant_access(VaultPid, UserId, AccessLevel) ->
  gen_server:call(VaultPid, {grant_access, UserId, AccessLevel}).

%% @doc Revoke user access to entire vault
-spec revoke_access(pid(), binary()) -> {ok, revoked} | {error, term()}.
revoke_access(VaultPid, UserId) ->
  gen_server:call(VaultPid, {revoke_access, UserId}).

%% @doc Store encrypted shard in vault
-spec store_shard(pid(), binary(), binary(), binary()) -> {ok, binary()} | {error, term()}.
store_shard(VaultPid, ShardId, EncryptedBlob, CallerId) ->
  gen_server:call(VaultPid, {store_shard, ShardId, EncryptedBlob, CallerId}).

%% @doc Get encrypted shard from vault
-spec get_shard(pid(), binary(), binary()) -> {ok, binary()} | {error, term()}.
get_shard(VaultPid, ShardId, CallerId) ->
  gen_server:call(VaultPid, {get_shard, ShardId, CallerId}).

%% @doc List all shard IDs in vault
-spec list_shards(pid()) -> {ok, list()} | {error, term()}.
list_shards(VaultPid) ->
  gen_server:call(VaultPid, list_shards).

%% @doc Get all vault-level permissions
-spec get_vault_permissions(pid()) -> {ok, map()} | {error, term()}.
get_vault_permissions(VaultPid) ->
  gen_server:call(VaultPid, get_vault_permissions).
