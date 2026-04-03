%%%-------------------------------------------------------------------
%% @doc Vault OTP application callback module
%% Starts the vault application supervision tree
%%%-------------------------------------------------------------------
-module(vault_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
  vault_sup:start_link().

stop(_State) ->
  ok.
