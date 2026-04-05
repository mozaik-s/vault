%%%-------------------------------------------------------------------
%% @doc Vault audit logging
%% Library module (no gen_server) for structured audit trail via Erlang logger
%%%-------------------------------------------------------------------
-module(vault_audit).

%% API - simple logging functions
-export([
  log_access/4,
  list_audit_log/1
]).

%% @doc Log an access event
%% VaultId, UserId, Action, Timestamp
-spec log_access(binary(), binary(), binary(), integer()) -> ok.
log_access(VaultId, UserId, Action, Timestamp) ->
  % Log via Erlang logger with structured metadata
  logger:info("Audit access: vault=~p user=~p action=~p timestamp=~p",
    [VaultId, UserId, Action, Timestamp],
    #{vault_id => VaultId, user_id => UserId, action => Action, timestamp => Timestamp}),
  ok.

%% @doc Retrieve audit log for a vault
%% TODO: Phase 2 - fetch from CouchDB
%% MVP: Returns empty list (audit trails logged to file only)
-spec list_audit_log(binary()) -> {ok, list()} | {error, term()}.
list_audit_log(VaultId) ->
  logger:debug("Retrieving audit log for vault ~p", [VaultId]),
  {ok, []}.
