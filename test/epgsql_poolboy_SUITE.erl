-module(epgsql_poolboy_SUITE).


-compile(export_all).

-include_lib("common_test/include/ct.hrl").

all() ->
    [simple_connect, transaction, fail_connect].

ensure_all_started(App) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, _}} ->
            ok;
        {error, {not_started, Dep}} ->
            ok = ensure_all_started(Dep),
            ensure_all_started(App)
    end.

init_per_suite(Config) ->
    ok = ensure_all_started(epgsql_poolboy),
    Config.

end_per_suite(_Config) ->
    application:stop(epgsql_poolboy).

create_pool(PoolName) ->
    SizeArgs = [{size, 10},
                {max_overflow, 20}],

    WorkerArgs = [{host, "localhost"},
                  {opts, [{database, "epgsql_test_database"}]}],

    epgsql_poolboy:start_pool(PoolName, SizeArgs, WorkerArgs).

simple_connect(_Config) ->
    PoolName = postgres_pool,
    {ok, Pid} = create_pool(PoolName),
    true = is_process_alive(Pid),
    ok = epgsql_poolboy:stop_pool(PoolName),
    false = is_process_alive(Pid).

transaction(_Config) ->
    PoolName = postgres_pool,
    {ok, Pid} = create_pool(PoolName),
    InTransaction =
        fun(C) ->
                {ok, _, Rows} = pgsql:equery(C, "SELECT * FROM test_database"),
                Next =
                    case Rows of
                        [] -> 0;
                        [_|_] ->
                            lists:max([N || {N} <- Rows]) + 1
                    end,
                {ok, 1} = pgsql:equery(C, "INSERT INTO test_database VALUES($1)", [Next])
        end,

    {ok, 1} = epgsql_poolboy:with_transaction(PoolName, InTransaction),
    {ok, 1} = epgsql_poolboy:with_transaction(PoolName, postgrestest, InTransaction, 5000),
    ok = epgsql_poolboy:stop_pool(PoolName),
    false = is_process_alive(Pid).

fail_connect(_Config) ->
    PoolName = postgres_pool,
    SizeArgs = [{size, 10},
                {max_overflow, 20}],

    WorkerArgs = [{host, "localhost"},
                  {opts, [{database, "epgsql_test_database"},
                          {port, 1}]}],

    {ok, _} = epgsql_poolboy:start_pool(PoolName, SizeArgs, WorkerArgs),
    {error, not_connected} = epgsql_poolboy:with_transaction(PoolName, fun(_) -> ok end).
