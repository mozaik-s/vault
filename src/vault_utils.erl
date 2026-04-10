%%%-------------------------------------------------------------------
%% @doc Shared utility functions for the vault application
%%%-------------------------------------------------------------------
-module(vault_utils).

-export([hash_id/1]).

-define(HASH_ALGORITHM, sha256).

%% @doc Hash a user ID for storage in the permissions map
-spec hash_id(binary()) -> binary().
hash_id(UserId) ->
  crypto:hash(?HASH_ALGORITHM, UserId).
