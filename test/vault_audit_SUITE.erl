%%%-------------------------------------------------------------------
%% Common Test suite for vault_audit — audit trail persistence
%%%-------------------------------------------------------------------
-module(vault_audit_SUITE).

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
    test_log_and_list_roundtrip/1,
    test_list_empty_vault/1,
    test_audit_from_vault_operations/1
]).

-spec all() -> [atom()].
-spec init_per_suite(list()) -> list().
-spec end_per_suite(list()) -> ok.
-spec init_per_testcase(atom(), list()) -> list().
-spec end_per_testcase(atom(), list()) -> ok.
-spec test_log_and_list_roundtrip(list()) -> ok.
-spec test_list_empty_vault(list()) -> ok.
-spec test_audit_from_vault_operations(list()) -> ok.

%% ===================================================================
%% Suite callbacks
%% ===================================================================

all() ->
    [
        test_log_and_list_roundtrip,
        test_list_empty_vault,
        test_audit_from_vault_operations
    ].

init_per_suite(Config) ->
    case application:ensure_started(vault) of
        ok -> ok;
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
%% Test cases
%% ===================================================================

test_log_and_list_roundtrip(_Config) ->
    VaultId = <<"vault_audit_1">>,
    ok = vault_audit:log_access(VaultId, <<"user_a">>, <<"store_shard">>, 1000),
    ok = vault_audit:log_access(VaultId, <<"user_b">>, <<"get_shard">>, 2000),
    {ok, Events} = vault_audit:list_audit_log(VaultId),
    2 = length(Events),
    [First, Second] = Events,
    <<"store_shard">> = maps:get(action, First),
    <<"user_a">> = maps:get(user_id, First),
    <<"get_shard">> = maps:get(action, Second),
    <<"user_b">> = maps:get(user_id, Second),
    ok.

test_list_empty_vault(_Config) ->
    {ok, []} = vault_audit:list_audit_log(<<"vault_audit_empty">>),
    ok.

test_audit_from_vault_operations(_Config) ->
    VaultId = <<"vault_audit_ops_3">>,
    OwnerId = <<"owner_audit_3">>,
    {ok, Pid} = vault:start_link(VaultId, OwnerId),
    {ok, _} = vault:store_shard(Pid, <<"shard_a">>, <<"blob">>, OwnerId),
    {ok, _} = vault:get_shard(Pid, <<"shard_a">>, OwnerId),
    {ok, Events} = vault:list_audit_log(VaultId),
    true = length(Events) >= 2,
    Actions = [maps:get(action, E) || E <- Events],
    true = lists:member(<<"store_shard">>, Actions),
    true = lists:member(<<"get_shard">>, Actions),
    ok.
