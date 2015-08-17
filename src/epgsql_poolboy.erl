-module(epgsql_poolboy).

-export([bind/3]).
-export([bind/4]).
-export([bind/5]).
-export([equery/2]).
-export([equery/3]).
-export([equery/4]).
-export([execute/2]).
-export([execute/3]).
-export([execute/4]).
-export([execute/5]).
-export([parse/2]).
-export([parse/3]).
-export([parse/4]).
-export([parse/5]).
-export([squery/2]).
-export([squery/3]).
-export([start_pool/3]).
-export([stop_pool/1]).
-export([sync/1]).
-export([sync/2]).
-export([with_transaction/2]).
-export([with_transaction/3]).
-export([with_transaction/4]).

-include("defaults.hrl").

-define(TIMEOUT, 5000).


-spec
start_pool(atom(), list(term()), list(term())) ->
    supervisor:startlink_ret().
start_pool(Name, SizeArgs, WorkerArgs) ->
    epgsql_poolboy_sup:start_pool(Name, SizeArgs, WorkerArgs).

-spec
stop_pool(atom()) ->
    ok | stop_return().
stop_pool(Name) ->
    epgsql_poolboy_sup:stop_pool(Name).

equery(PoolNameOrAtom, Sql) ->
    equery(PoolNameOrAtom, Sql, []).

equery(PoolNameOrAtom, Sql, Args) ->
    equery(PoolNameOrAtom, Sql, Args, ?TIMEOUT).

equery(PoolNameOrAtom, Sql, Args, Timeout) ->
    exec(PoolNameOrAtom, {equery, [Sql, Args]}, Timeout).

squery(PoolNameOrAtom, Sql) ->
    squery(PoolNameOrAtom, Sql, ?TIMEOUT).

squery(PoolNameOrAtom, Sql, Timeout) ->
    exec(PoolNameOrAtom, {squery, [Sql]}, Timeout).

parse(PoolNameOrAtom, Sql) ->
    parse(PoolNameOrAtom, "", Sql, []).

parse(PoolNameOrAtom, Sql, Types) ->
    parse(PoolNameOrAtom, "", Sql, Types).

parse(PoolNameOrAtom, Name, Sql, Types) ->
    parse(PoolNameOrAtom, Name, Sql, Types, ?TIMEOUT).

parse(PoolNameOrAtom, Name, Sql, Types, Timeout) ->
    exec(PoolNameOrAtom, {parse, [PoolNameOrAtom, Name, Sql, Types]}, Timeout).

bind(PoolNameOrAtom, Statement, Parameters) ->
    bind(PoolNameOrAtom, Statement, "", Parameters).

bind(PoolNameOrAtom, Statement, PortalName, Parameters) ->
    bind(PoolNameOrAtom, Statement, PortalName, Parameters, ?TIMEOUT).

bind(PoolNameOrAtom, Statement, PortalName, Parameters, Timeout) ->
    exec(PoolNameOrAtom, {bind, [Statement, PortalName, Parameters]}, Timeout).

execute(PoolNameOrAtom, S) ->
    execute(PoolNameOrAtom, S, "", 0).

execute(PoolNameOrAtom, S, N) ->
    execute(PoolNameOrAtom, S, "", N).

execute(PoolNameOrAtom, S, PortalName, N) ->
    execute(PoolNameOrAtom, S, PortalName, N, ?TIMEOUT).

execute(PoolNameOrAtom, S, PortalName, N, Timeout) ->
    exec(PoolNameOrAtom, {execute, [S, PortalName, N]}, Timeout).

sync(PoolNameOrAtom) ->
    sync(PoolNameOrAtom, ?TIMEOUT).

sync(PoolNameOrAtom, Timeout) ->
    exec(PoolNameOrAtom, sync, Timeout).

with_transaction(PoolNameOrAtom, F) ->
    with_transaction(PoolNameOrAtom, F, ?TIMEOUT).

with_transaction(PoolNameOrAtom, F, Timeout) ->
    with_transaction(PoolNameOrAtom, unnamed, F, Timeout).

with_transaction(PoolNameOrAtom, QueryName, F, Timeout) ->
    exec(PoolNameOrAtom, QueryName, {with_transaction, [F]}, Timeout).

exec(Worker, Args, Timeout) ->
    exec(Worker, unnamed, Args, Timeout).

exec(Worker, _QueryName, Args, Timeout) when is_pid(Worker) ->
    gen_server:call(Worker, Args, Timeout);
exec(PoolName, QueryName, Args, Timeout) ->
    PoolNameBin = atom_to_binary(PoolName, latin1),
    QueryNameBin = atom_to_binary(QueryName, latin1),
    BaseMetricName = [<<"epgsql_poolboy.">>, PoolNameBin, ".", QueryNameBin, stat(Args)],
    NameTimer = list_to_binary(BaseMetricName),
    NameSpiral = list_to_binary([<<"epgsql_poolboy.">>, PoolNameBin, stat(Args), ".counter"]),
    Fun = fun(Worker) ->
                  Metric = quintana:begin_timed(NameTimer),
                  Res = gen_server:call(Worker, Args, Timeout),
                  ok = quintana:notify_timed(Metric),
                  ok = quintana:notify_spiral({NameSpiral, 1}),
                  Res
          end,
    poolboy:transaction(PoolName, Fun, Timeout).

stat({F, _}) when is_atom(F) ->
    append_stat(F);
stat(F) when is_atom(F) ->
    append_stat(F).

append_stat(F) when is_atom(F) ->
    BinFuncName = atom_to_binary(F, latin1),
    <<".", BinFuncName/binary>>.
