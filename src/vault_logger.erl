%%%-------------------------------------------------------------------
%% @doc Vault logging configuration
%% Configures Erlang logger handlers (console + file) at application start.
%% All settings are overridable via environment variables:
%%   VAULT_LOG_LEVEL         - debug | info | warning | error  (default: info)
%%   VAULT_LOG_FILE          - path to log file                (default: vault.log)
%%   VAULT_LOG_CONSOLE       - true | false                    (default: true)
%%   VAULT_LOG_FILE_ENABLED  - true | false                    (default: true)
%%%-------------------------------------------------------------------
-module(vault_logger).

-export([configure/0]).

%% @doc Configure Erlang logger with console and file handlers
-spec configure() -> ok.
configure() ->
  LogLevel = log_level(),

  case console_enabled() of
    true ->
      ok = logger:add_handler(console, logger_std_h, #{
        level => LogLevel,
        formatter => {logger_formatter, #{
          template => [time, " [", level, "] ", pid, " ", mfa, ":", line, " ", msg, "\n"]
        }}
      });
    false ->
      ok
  end,

  case file_enabled() of
    true ->
      ok = logger:add_handler(file, logger_disk_log_h, #{
        config => #{
          file => log_file(),
          type => wrap,
          max_no_files => 10,
          max_no_bytes => 10485760
        },
        level => LogLevel,
        formatter => {logger_formatter, #{
          template => [time, " [", level, "] ", pid, " ", mfa, ":", line, " ", msg, "\n"]
        }}
      });
    false ->
      ok
  end,

  logger:set_primary_config(level, LogLevel),
  ok.

-spec log_level() -> atom().
log_level() ->
  case os:getenv("VAULT_LOG_LEVEL") of
    false     -> info;
    "debug"   -> debug;
    "info"    -> info;
    "warning" -> warning;
    "error"   -> error;
    _         -> info
  end.

-spec log_file() -> string().
log_file() ->
  case os:getenv("VAULT_LOG_FILE") of
    false -> "vault.log";
    Path  -> Path
  end.

-spec console_enabled() -> boolean().
console_enabled() ->
  case os:getenv("VAULT_LOG_CONSOLE") of
    "false" -> false;
    "0"     -> false;
    _       -> true
  end.

-spec file_enabled() -> boolean().
file_enabled() ->
  case os:getenv("VAULT_LOG_FILE_ENABLED") of
    "false" -> false;
    "0"     -> false;
    _       -> true
  end.
