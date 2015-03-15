-module(worker).

-compile([export_all]).

create() ->
	spawn(?MODULE, server_loop, [[], not_a_pid]). 

new() ->
    Pid = create(),
    mrs:register_worker(Pid),
    Pid.

server_loop(Numbers, ReplicaHost) ->	    
    receive
	{map, From, Fun} ->
	    io:format("Mapping (~p)~n", [self()]),
	    %entries in this list have the format: {Key, Value}
	    ResultList = lists:map(Fun, Numbers),
	    From ! {map_result, self(), ResultList},
	    server_loop(Numbers, ReplicaHost);
	{store, Int} ->
	    %io:format("Storing ~p~n", [Int]),
	    send_to_replica(Int, ReplicaHost),
	    server_loop([Int|Numbers], ReplicaHost);
        {rebalance, From, NumWorkers, ExpectedIndex} ->
    	    DataToKeep = lists:filter(fun(X) -> ExpectedIndex =:= (X rem NumWorkers) end, Numbers),
    	    DataToPurge = lists:filter(fun(X) -> ExpectedIndex =/= (X rem NumWorkers) end, Numbers),
    	    From ! {purged_data, DataToPurge},
    	    server_loop(DataToKeep, ReplicaHost);
	{reset} ->
	    server_loop([], ReplicaHost); %TODO: delete replica
	{print} ->
	    io:format(" ~p: ~w~n", [self(), Numbers]),
	    server_loop(Numbers, ReplicaHost);
	{replicate_to, DestinationServer} ->
	    io:format("Replicating to: ~p~n", [DestinationServer]),
	    DestinationServer ! {full_replica, self(), Numbers},
	    server_loop(Numbers, DestinationServer)
    end.

send_to_replica(_Int, not_a_pid) ->
	ok;
send_to_replica(Int, DestinationServer) ->
	DestinationServer ! {append_replica, self(), Int},
	ok.
