%%%-------------------------------------------------------------------
%% @doc Vault application supervisor
%% Manages supporting services: vault instance manager (registry)
%% Does NOT manage individual vault processes (managed by vault_mgr)
%% Database, crypto, and audit are now library modules (no gen_servers)
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
    % Vault instance manager (registry/pool)
    #{
      id => vault_mgr,
      start => {vault_mgr, start_link, []},
      type => worker,
      shutdown => 5000
    }
  ],

  {ok, {SupFlags, ChildSpecs}}.
