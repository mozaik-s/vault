#!/usr/bin/env escript
%% Print a coverage summary from CT's all.coverdata

main([CoverData]) ->
    cover:start(),
    case cover:import(CoverData) of
        ok ->
            Mods = lists:sort(cover:imported_modules()),
            io:format("~n~-28s  ~s~n", ["Module", "Coverage"]),
            io:format("~s~n", [lists:duplicate(40, $-)]),
            lists:foreach(fun print_mod_coverage/1, Mods),
            io:format("~n");
        {error, Reason} ->
            io:format("Could not import cover data: ~p~n", [Reason])
    end.

print_mod_coverage(M) ->
    case cover:analyse(M, coverage, module) of
        {ok, {M, {Cov, Not}}} when Cov + Not > 0 ->
            Pct = round(100 * Cov / (Cov + Not)),
            Bar = lists:duplicate(Pct div 5, $#),
            io:format("~-28w  ~3w%  [~-20s]~n", [M, Pct, Bar]);
        _ ->
            ok
    end.
