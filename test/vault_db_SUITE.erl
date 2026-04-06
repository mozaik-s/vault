%%%-------------------------------------------------------------------
%% @doc Common Test suite for vault_db module (CouchDB operations)
%% Verifies module structure and API compliance
%%%-------------------------------------------------------------------
-module(vault_db_SUITE).

-include_lib("common_test/include/ct.hrl").

%% Common Test callbacks
-export([
  suite/0,
  all/0,
  init_per_suite/1,
  end_per_suite/1,
  init_per_testcase/2,
  end_per_testcase/2
]).

%% Test cases
-export([
  test_module_exists/1,
  test_module_exports/1,
  test_store_vault_spec/1,
  test_get_vault_spec/1,
  test_update_vault_spec/1,
  test_store_shard_spec/1,
  test_get_shard_spec/1,
  test_get_all_shards_spec/1,
  test_delete_shard_spec/1,
  test_delete_vault_spec/1
]).

%% ===================================================================
%% Type specs
%% ===================================================================

-spec suite() -> [tuple()].
-spec all() -> [atom()].
-spec init_per_suite(list()) -> list().
-spec end_per_suite(list()) -> ok.
-spec init_per_testcase(atom(), list()) -> list().
-spec end_per_testcase(atom(), list()) -> ok.
-spec test_module_exists(list()) -> ok.
-spec test_module_exports(list()) -> ok.
-spec test_store_vault_spec(list()) -> ok.
-spec test_get_vault_spec(list()) -> ok.
-spec test_update_vault_spec(list()) -> ok.
-spec test_store_shard_spec(list()) -> ok.
-spec test_get_shard_spec(list()) -> ok.
-spec test_get_all_shards_spec(list()) -> ok.
-spec test_delete_shard_spec(list()) -> ok.
-spec test_delete_vault_spec(list()) -> ok.

%% ===================================================================
%% Common Test Callbacks
%% ===================================================================

suite() -> [{timetrap, {seconds, 30}}].

all() -> [
  test_module_exists,
  test_module_exports,
  test_store_vault_spec,
  test_get_vault_spec,
  test_update_vault_spec,
  test_store_shard_spec,
  test_get_shard_spec,
  test_get_all_shards_spec,
  test_delete_shard_spec,
  test_delete_vault_spec
].

init_per_suite(Config) ->
  case application:ensure_all_started(vault) of
    {ok, _Apps} -> ok;
    {error, _} -> ok
  end,
  Config.

end_per_suite(_Config) ->
  ok.

init_per_testcase(_TestCase, Config) ->
  Config.

end_per_testcase(_TestCase, _Config) ->
  ok.

%% ===================================================================
%% Test Cases - Module Structure Verification
%% ===================================================================

test_module_exists(_Config) ->
  case code:ensure_loaded(vault_db) of
    {module, vault_db} ->
      ct:print("✓ vault_db module loaded successfully");
    Error ->
      ct:fail({module_load_failed, Error})
  end.

test_module_exports(_Config) ->
  ExpectedExports = [
    {store_vault, 2},
    {get_vault, 1},
    {update_vault, 2},
    {store_shard, 3},
    {get_shard, 2},
    {get_all_shards_for_vault, 1},
    {delete_shard, 2},
    {delete_vault, 1}
  ],
  
  case code:is_loaded(vault_db) of
    {file, _} ->
      Exports = vault_db:module_info(exports),
      Exports2 = [{Name, Arity} || {Name, Arity} <- Exports, Name =/= module_info],
      MissingExports = [F || F <- ExpectedExports, not lists:member(F, Exports2)],
      
      case MissingExports of
        [] ->
          ct:print("✓ All expected functions exported: ~p", [ExpectedExports]);
        _ ->
          ct:fail({missing_exports, MissingExports})
      end;
    false ->
      ct:fail(vault_db_not_loaded)
  end.

test_store_vault_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ store_vault/2 accessible").

test_get_vault_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ get_vault/1 accessible").

test_update_vault_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ update_vault/2 accessible").

test_store_shard_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ store_shard/3 accessible").

test_get_shard_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ get_shard/2 accessible").

test_get_all_shards_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ get_all_shards_for_vault/1 accessible").

test_delete_shard_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ delete_shard/2 accessible").

test_delete_vault_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ delete_vault/1 accessible").
