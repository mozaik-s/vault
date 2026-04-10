%%%-------------------------------------------------------------------
%% @doc Vault OTP application callback module
%%%-------------------------------------------------------------------
-module(vault_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    vault_logger:configure(),
    vault_sup:start_link().

stop(_State) ->
    ok.
