%%%-------------------------------------------------------------------
%% @doc Common Test suite for vault_shards module
%% Verifies module structure and API compliance
%%%-------------------------------------------------------------------
-module(vault_shards_SUITE).

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
    test_module_exports/1
]).

-spec suite() -> [tuple()].
-spec all() -> [atom()].
-spec init_per_suite(list()) -> list().
-spec end_per_suite(list()) -> ok.
-spec init_per_testcase(atom(), list()) -> list().
-spec end_per_testcase(atom(), list()) -> ok.
-spec test_module_exists(list()) -> ok.
-spec test_module_exports(list()) -> ok.

suite() -> [{timetrap, {seconds, 30}}].

all() ->
    [
        test_module_exists,
        test_module_exports
    ].

init_per_suite(Config) ->
    case application:ensure_all_started(vault) of
        {ok, _Apps} -> ok;
        {error, _} -> ok
    end,
    Config.

end_per_suite(_Config) -> ok.

init_per_testcase(_TestCase, Config) -> Config.

end_per_testcase(_TestCase, _Config) -> ok.

%% ===================================================================
%% Test Cases
%% ===================================================================

test_module_exists(_Config) ->
    case code:ensure_loaded(vault_shards) of
        {module, vault_shards} ->
            ct:print("✓ vault_shards module loaded successfully");
        Error ->
            ct:fail({module_load_failed, Error})
    end.

test_module_exports(_Config) ->
    ExpectedExports = [
        {store_shard, 3},
        {get_shard, 2},
        {get_all_shards_for_vault, 1},
        {delete_shard, 2}
    ],
    {file, _} = code:is_loaded(vault_shards),
    Exports = [
        {Name, Arity}
     || {Name, Arity} <- vault_shards:module_info(exports),
        Name =/= module_info
    ],
    MissingExports = [F || F <- ExpectedExports, not lists:member(F, Exports)],
    case MissingExports of
        [] -> ct:print("✓ All expected functions exported: ~p", [ExpectedExports]);
        _ -> ct:fail({missing_exports, MissingExports})
    end.
