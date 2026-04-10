%%%-------------------------------------------------------------------
%% @doc Vault process pool - registry and lifecycle management
%% Manages creation, retrieval, and termination of vault processes.
%% Implements on-demand vault process spawning with timeout cleanup.
%%%-------------------------------------------------------------------
-module(vault_pool).

-behaviour(gen_server).

%% API
-export([
    start_link/0,
    get_or_create_vault/2,
    revoke_vault/1,
    list_active_vaults/0
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

%% State: #{vaults => #{VaultId => {Pid, StartTime}}}

%% ===================================================================
%% API
%% ===================================================================

%% @doc Start the vault pool
-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Get existing vault process or create a new one
-spec get_or_create_vault(binary(), map()) -> {ok, pid()} | {error, term()}.
get_or_create_vault(VaultId, Options) ->
    gen_server:call(?MODULE, {get_or_create_vault, VaultId, Options}).

%% @doc Stop a vault process and remove it from the pool
-spec revoke_vault(binary()) -> ok | {error, term()}.
revoke_vault(VaultId) ->
    gen_server:call(?MODULE, {revoke_vault, VaultId}).

%% @doc List all currently active vault IDs
-spec list_active_vaults() -> {ok, list()} | {error, term()}.
list_active_vaults() ->
    gen_server:call(?MODULE, list_active_vaults).

%% ===================================================================
%% gen_server callbacks
%% ===================================================================

init([]) ->
    {ok, #{vaults => #{}}}.

handle_call({get_or_create_vault, VaultId, Options}, _From, State) ->
    Vaults = maps:get(vaults, State),
    case maps:find(VaultId, Vaults) of
        {ok, {Pid, _StartTime}} ->
            logger:debug("Vault ~p already active, returning existing process", [VaultId]),
            {reply, {ok, Pid}, State};
        error ->
            OwnerId = maps:get(owner_id, Options, undefined),
            case vault:start_link(VaultId, OwnerId) of
                {ok, Pid} ->
                    StartTime = erlang:system_time(millisecond),
                    NewState = State#{vaults => Vaults#{VaultId => {Pid, StartTime}}},
                    logger:info("Created new vault process ~p for vault_id ~p", [Pid, VaultId]),
                    {reply, {ok, Pid}, NewState};
                {error, Reason} ->
                    logger:error("Failed to create vault ~p: ~p", [VaultId, Reason]),
                    {reply, {error, Reason}, State}
            end
    end;
handle_call({revoke_vault, VaultId}, _From, State) ->
    Vaults = maps:get(vaults, State),
    case maps:find(VaultId, Vaults) of
        {ok, {Pid, _StartTime}} ->
            gen_server:stop(Pid),
            NewState = State#{vaults => maps:remove(VaultId, Vaults)},
            logger:info("Revoked vault ~p", [VaultId]),
            {reply, ok, NewState};
        error ->
            {reply, {error, vault_not_found}, State}
    end;
handle_call(list_active_vaults, _From, State) ->
    VaultIds = maps:keys(maps:get(vaults, State)),
    {reply, {ok, VaultIds}, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
