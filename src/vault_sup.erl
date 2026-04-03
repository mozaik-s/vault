%%%-------------------------------------------------------------------
%% @doc Vault application supervisor
%% Manages supporting services: database, crypto, audit logging
%% Does NOT manage individual vault processes (managed by vault_mgr)
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
    % Vault database connection pool
    #{
      id => vault_db,
      start => {vault_db, start_link, []},
      type => worker,
      shutdown => 5000
    },
    
    % Vault cryptographic service
    #{
      id => vault_crypto,
      start => {vault_crypto, start_link, []},
      type => worker,
      shutdown => 5000
    },
    
    % Vault audit logger
    #{
      id => vault_audit,
      start => {vault_audit, start_link, []},
      type => worker,
      shutdown => 5000
    },
    
    % Vault instance manager (registry/pool)
    #{
      id => vault_mgr,
      start => {vault_mgr, start_link, []},
      type => worker,
      shutdown => 5000
    }
  ],

  {ok, {SupFlags, ChildSpecs}}.
