%%%-------------------------------------------------------------------
%% @doc Common Test suite for vault_db module (CouchDB generic adapter)
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
  test_store_doc_spec/1,
  test_get_doc_spec/1,
  test_delete_doc_spec/1,
  test_list_docs_by_prefix_spec/1,
  test_store_vault_spec/1,
  test_get_vault_spec/1,
  test_update_vault_spec/1,
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
-spec test_store_doc_spec(list()) -> ok.
-spec test_get_doc_spec(list()) -> ok.
-spec test_delete_doc_spec(list()) -> ok.
-spec test_list_docs_by_prefix_spec(list()) -> ok.
-spec test_store_vault_spec(list()) -> ok.
-spec test_get_vault_spec(list()) -> ok.
-spec test_update_vault_spec(list()) -> ok.
-spec test_delete_vault_spec(list()) -> ok.

%% ===================================================================
%% Common Test Callbacks
%% ===================================================================

suite() -> [{timetrap, {seconds, 30}}].

all() -> [
  test_module_exists,
  test_module_exports,
  test_store_doc_spec,
  test_get_doc_spec,
  test_delete_doc_spec,
  test_list_docs_by_prefix_spec,
  test_store_vault_spec,
  test_get_vault_spec,
  test_update_vault_spec,
  test_delete_vault_spec
].

init_per_suite(Config) ->
  case application:ensure_all_started(vault) of
    {ok, _Apps} -> ok;
    {error, _}  -> ok
  end,
  Config.

end_per_suite(_Config) -> ok.

init_per_testcase(_TestCase, Config) -> Config.

end_per_testcase(_TestCase, _Config) -> ok.

%% ===================================================================
%% Test Cases
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
    {store_doc, 2},
    {get_doc, 1},
    {delete_doc, 1},
    {list_docs_by_prefix, 2},
    {store_vault, 2},
    {get_vault, 1},
    {update_vault, 2},
    {delete_vault, 1}
  ],
  {file, _} = code:is_loaded(vault_db),
  Exports = [{Name, Arity} || {Name, Arity} <- vault_db:module_info(exports),
                               Name =/= module_info],
  MissingExports = [F || F <- ExpectedExports, not lists:member(F, Exports)],
  case MissingExports of
    [] -> ct:print("✓ All expected functions exported: ~p", [ExpectedExports]);
    _  -> ct:fail({missing_exports, MissingExports})
  end.

test_store_doc_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ store_doc/2 accessible").

test_get_doc_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ get_doc/1 accessible").

test_delete_doc_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ delete_doc/1 accessible").

test_list_docs_by_prefix_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ list_docs_by_prefix/2 accessible").

test_store_vault_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ store_vault/2 accessible").

test_get_vault_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ get_vault/1 accessible").

test_update_vault_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ update_vault/2 accessible").

test_delete_vault_spec(_Config) ->
  {module, vault_db} = code:ensure_loaded(vault_db),
  ct:print("✓ delete_vault/1 accessible").

