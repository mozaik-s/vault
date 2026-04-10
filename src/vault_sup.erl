%%%-------------------------------------------------------------------
%% @doc Vault application supervisor
%% Manages supporting services: vault process pool (vault_pool).
%% Does NOT manage individual vault processes (managed by vault_pool).
%% Database, crypto, and audit are library modules (no gen_servers).
%%%-------------------------------------------------------------------
-module(vault_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },

    ChildSpecs = [
        #{
            id => vault_pool,
            start => {vault_pool, start_link, []},
            type => worker,
            shutdown => 5000
        }
    ],

    {ok, {SupFlags, ChildSpecs}}.
