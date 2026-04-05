%%%-------------------------------------------------------------------
%% @doc Vault OTP application callback module
%% Starts the vault application supervision tree and configures logging
%%%-------------------------------------------------------------------
-module(vault_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
  configure_logging(),
  vault_sup:start_link().

stop(_State) ->
  ok.

%% Internal functions

%% @doc Configure Erlang logger with console and file handlers
%% Environment variables override defaults:
%% - VAULT_LOG_LEVEL: debug, info, warning, error (default: info)
%% - VAULT_LOG_FILE: path to log file (default: vault.log)
%% - VAULT_LOG_CONSOLE: true/false (default: true)
%% - VAULT_LOG_FILE_ENABLED: true/false (default: true)
-spec configure_logging() -> ok.
configure_logging() ->
  LogLevel = log_level(),
  LogFile = log_file(),
  ConsoleEnabled = console_enabled(),
  FileEnabled = file_enabled(),
  
  % Configure console handler
  case ConsoleEnabled of
    true ->
      ok = logger:add_handler(console, logger_std_h, #{
        level => LogLevel,
        formatter => {logger_formatter, #{
          template => [time, " [", level, "] ", pid, " ", mfa, ":", line, " ", msg, "\n"],
          time_designator => " "
        }}
      });
    false ->
      ok
  end,
  
  % Configure file handler
  case FileEnabled of
    true ->
      ok = logger:add_handler(file, logger_disk_log_h, #{
        config => #{
          file => LogFile,
          type => wrap,
          max_no_files => 10,
          max_no_bytes => 10485760  % 10MB per file
        },
        level => LogLevel,
        formatter => {logger_formatter, #{
          template => [time, " [", level, "] ", pid, " ", mfa, ":", line, " ", msg, "\n"],
          time_designator => " "
        }}
      });
    false ->
      ok
  end,
  
  logger:set_primary_config(level, LogLevel),
  ok.

%% @doc Get log level from environment or default to info
-spec log_level() -> atom().
log_level() ->
  case os:getenv("VAULT_LOG_LEVEL") of
    false -> info;
    "debug" -> debug;
    "info" -> info;
    "warning" -> warning;
    "error" -> error;
    _ -> info
  end.

%% @doc Get log file path from environment or default
-spec log_file() -> string().
log_file() ->
  case os:getenv("VAULT_LOG_FILE") of
    false -> "vault.log";
    Path -> Path
  end.

%% @doc Check if console logging is enabled (default: true)
-spec console_enabled() -> boolean().
console_enabled() ->
  case os:getenv("VAULT_LOG_CONSOLE") of
    "false" -> false;
    "0" -> false;
    _ -> true
  end.

%% @doc Check if file logging is enabled (default: true)
-spec file_enabled() -> boolean().
file_enabled() ->
  case os:getenv("VAULT_LOG_FILE_ENABLED") of
    "false" -> false;
    "0" -> false;
    _ -> true
  end.
