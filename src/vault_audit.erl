%%%-------------------------------------------------------------------
%% @doc Vault audit logging service
%% Tracks all access and modifications for compliance and security
%%%-------------------------------------------------------------------
-module(vault_audit).

-behaviour(gen_server).

%% API
-export([
  start_link/0,
  log_access/4,
  list_audit_log/1
]).

%% gen_server callbacks
-export([
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3
]).

-record(state, {
  logs = [] :: list()
}).

%% ===================================================================
%% API
%% ===================================================================

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Log an access event
%% VaultId, UserId, Action, Timestamp
-spec log_access(binary(), binary(), binary(), integer()) -> ok.
log_access(VaultId, UserId, Action, Timestamp) ->
  gen_server:cast(?MODULE, {log_access, VaultId, UserId, Action, Timestamp}).

%% @doc Retrieve audit log for a vault
-spec list_audit_log(binary()) -> {ok, list()} | {error, term()}.
list_audit_log(VaultId) ->
  gen_server:call(?MODULE, {list_audit_log, VaultId}).

%% ===================================================================
%% gen_server callbacks
%% ===================================================================

init([]) ->
  State = #state{logs = []},
  {ok, State}.

handle_call({list_audit_log, VaultId}, _From, State) ->
  % TODO: Filter logs by VaultId
  % TODO: Return filtered logs from CouchDB or in-memory store
  logger:debug("Retrieving audit log for vault ~p", [VaultId]),
  {reply, {ok, []}, State};

handle_call(_Request, _From, State) ->
  {reply, {error, unknown_call}, State}.

handle_cast({log_access, VaultId, UserId, Action, Timestamp}, State) ->
  % TODO: Store log entry in CouchDB
  logger:debug("Audit: Vault ~p User ~p Action ~p at ~p", [VaultId, UserId, Action, Timestamp]),
  {noreply, State};

handle_cast(_Request, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
