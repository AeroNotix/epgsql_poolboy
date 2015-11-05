-module(epgsql_poolboy_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([start_pool/3]).
-export([stop_pool/1]).
-export([stop_pools/0]).
-export([init/1]).


start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec
start_pool(atom(), proplists:proplist(), proplists:proplist()) ->
    {ok, pid()} | {error, Reason :: term()}.
start_pool(Name, SizeArgs, WorkerArgs) when is_atom(Name) ->
    supervisor:start_child(?MODULE, [Name, SizeArgs, WorkerArgs]).

-spec
stop_pool(atom()) ->
    ok.
stop_pool(Name) ->
    epgsql_pool_sup:stop_child(Name).

-spec
stop_pools() ->
    ok.
stop_pools() ->
    [ok = supervisor:terminate_child(epgsql_poolboy_sup, Pid)
     || {_, Pid, _, _} <- supervisor:which_children(?MODULE)],
    ok.

init([]) ->
    {ok, {{simple_one_for_one, 1, 1},
          [{undefined,
            {epgsql_pool_sup, start_link, []},
            transient, 5000, worker, [epgsql_pool_sup]}]}}.
