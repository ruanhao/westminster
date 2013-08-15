%%%----------------------------------------------------------------------
%%% File      : westminster_actor.erl
%%% Author    : ryan.ruan@ericsson.com
%%% Purpose   : Westminster server
%%% Created   : Aug 12, 2013
%%%----------------------------------------------------------------------

%%%----------------------------------------------------------------------
%%% Copyright Ericsson AB 1996-2013. All Rights Reserved.
%%%
%%% The contents of this file are subject to the Erlang Public License,
%%% Version 1.1, (the "License"); you may not use this file except in
%%% compliance with the License. You should have received a copy of the
%%% Erlang Public License along with this software. If not, it can be
%%% retrieved online at http://www.erlang.org/.
%%%
%%% Software distributed under the License is distributed on an "AS IS"
%%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%%% the License for the specific language governing rights and limitations
%%% under the License.
%%%----------------------------------------------------------------------

-module(westminster_actor).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-define(MAX_DOWN_TIMES, 100).

-record(state, {central_node = undefined, 
                downtimes = 0}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    error_logger:info_msg("start to initialize cluster~n", []),
    do(init_config),
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(init_config, _) ->
    {ok, CentralNode} = application:get_env(central_node),
    do(connect_to_central_node),
    {noreply, #state{central_node = CentralNode}};

handle_info(connect_to_central_node, #state{central_node = CentralNode} = State) ->
    IsConnected = net_kernel:connect_node(CentralNode),
    case IsConnected of
        true ->
            do(connect_to_other_nodes),
            {noreply, State};
        false ->
            {stop, "central node unavailable", State}
    end;

handle_info(connect_to_other_nodes, #state{central_node = CentralNode} = State) ->
    NodesAroundCentral = rpc:call(CentralNode, erlang, nodes, []),
    connect_nodes(NodesAroundCentral, init),
    do(set_ticktime),
    {noreply, State};

handle_info(set_ticktime, #state{central_node = CentralNode} = State) ->
    Query = rpc:call(CentralNode, net_kernel, get_net_ticktime, []),
    Ticktime = case Query of
                   {ongoing_change_to, T} -> T;
                   ignored -> 60;
                   T -> T
               end,
    net_kernel:set_net_ticktime(Ticktime),
    error_logger:info_msg("cluster established (with ticktime synchronized)~n", []),
    do(monitor_nodes),
    {noreply, State};

handle_info(monitor_nodes, State) ->
    Nodes = nodes(connected),                % because this is a hidden node,
                                             % that's why *connected* is used.
    [erlang:monitor_node(N, true) || N <- Nodes],
    {noreply, State};

handle_info({nodedown, DownNode}, #state{downtimes = Times} = State) ->
    mark_unmeshed(),
    if
        Times > ?MAX_DOWN_TIMES -> 
            Msg = io_lib:format("too many times of node down, please check the network", []),
            exit(Msg);
        true -> 
            ok
    end,
    connect_nodes([DownNode], normal),
    erlang:monitor_node(DownNode, true),
    {noreply, State#state{downtimes = Times + 1}};
    
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
do(Something) ->
    timer:send_after(1000, Something).

connect_nodes([], init) ->
    mark_meshed(),
    error_logger:info_msg("cluster established (without ticktime synchronized)~n", []);

%% this clause is used to reconnect the down node
connect_nodes([], normal) ->
    mark_meshed(),
    error_logger:info_msg("cluster established~n", []);

connect_nodes([H | T], Stat) ->
    IsConnected = net_kernel:connect_node(H),
    case IsConnected of
        true ->
            error_logger:info_msg("connect to node (~w) successfully~n", [H]),
            connect_nodes(T, Stat);
        false ->
            Msg = io_lib:format("connect to node (" ++ atom_to_list(H) ++ ") unsuccessfully", []),
            exit(Msg)
    end.

mark_meshed() ->
    application:set_env(westminster, cluster_meshed, true).

mark_unmeshed() ->
    application:set_env(westminster, cluster_meshed, false).
