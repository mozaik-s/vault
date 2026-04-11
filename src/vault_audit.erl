%%%-------------------------------------------------------------------
%% @doc Vault audit logging
%% Library module (no gen_server) for structured audit trail
%% Persists audit events to CouchDB and provides query interface
%%%-------------------------------------------------------------------
-module(vault_audit).

-export([
    log_access/4,
    list_audit_log/1
]).

-define(AUDIT_PREFIX, <<"audit:">>).

%% @doc Log an access event to both logger and CouchDB
-spec log_access(binary(), binary(), binary(), integer()) -> ok.
log_access(VaultId, UserId, Action, Timestamp) ->
    logger:info(
        "Audit access: vault=~p user=~p action=~p timestamp=~p",
        [VaultId, UserId, Action, Timestamp],
        #{vault_id => VaultId, user_id => UserId, action => Action, timestamp => Timestamp}
    ),
    DocId = audit_doc_id(VaultId, Timestamp),
    Doc = #{
        <<"_id">> => DocId,
        <<"vault_id">> => VaultId,
        <<"user_id">> => UserId,
        <<"action">> => Action,
        <<"timestamp">> => Timestamp
    },
    case vault_db:store_doc(DocId, Doc) of
        {ok, _} ->
            ok;
        {error, Reason} ->
            logger:error("Failed to persist audit event ~p: ~p", [DocId, Reason]),
            ok
    end.

%% @doc Retrieve all audit events for a vault, ordered by timestamp
-spec list_audit_log(binary()) -> {ok, list()} | {error, term()}.
list_audit_log(VaultId) ->
    Prefix = <<(?AUDIT_PREFIX)/binary, VaultId/binary, ":">>,
    case vault_db:list_docs_by_prefix(Prefix, <<Prefix/binary, "~">>) of
        {ok, Docs} ->
            Events = [audit_doc_to_event(vault_db:ejson_to_map(D)) || D <- Docs],
            {ok, Events};
        {error, _} = E ->
            E
    end.

%% ===================================================================
%% Internal helpers
%% ===================================================================

audit_doc_id(VaultId, Timestamp) ->
    TsBin = integer_to_binary(Timestamp),
    <<(?AUDIT_PREFIX)/binary, VaultId/binary, ":", TsBin/binary>>.

audit_doc_to_event(
    #{
        <<"vault_id">> := _,
        <<"user_id">> := _,
        <<"action">> := _,
        <<"timestamp">> := _
    } = Event
) ->
    Event.
