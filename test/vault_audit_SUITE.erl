%%%-------------------------------------------------------------------
%% Common Test suite for vault_audit — audit trail persistence
%%%-------------------------------------------------------------------
-module(vault_audit_SUITE).

-include_lib("common_test/include/ct.hrl").

-compile(export_all).
-compile(nowarn_export_all).

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
    #{<<"action">> := <<"store_shard">>, <<"user_id">> := <<"user_a">>} = First,
    #{<<"action">> := <<"get_shard">>, <<"user_id">> := <<"user_b">>} = Second,
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
    Actions = [Action || #{<<"action">> := Action} <- Events],
    true = lists:member(<<"store_shard">>, Actions),
    true = lists:member(<<"get_shard">>, Actions),
    ok.
