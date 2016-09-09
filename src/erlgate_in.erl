%% ==========================================================================================================
%% ErlGate - An alternative transport for Erlang messages across nodes
%%
%% The MIT License (MIT)
%%
%% Copyright (c) 2016 Roberto Ostinelli <roberto@ostinelli.net>.
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.
%% ==========================================================================================================
-module(erlgate_in).
-behaviour(ranch_protocol).

%% ranch callbacks
-export([start_link/4]).
-export([init/4]).

%% records
-record(state, {
    transport = undefined :: atom(),
    socket = undefined :: any(),
    channel_id = "" :: string(),
    messages = undefined :: any(),
    dispatcher_module = undefined :: any(),
    dispatcher_options = undefined :: any()
}).

%% ===================================================================
%% Callbacks
%% ===================================================================
-spec start_link(Ref :: any(), Socket :: any(), Transport :: atom(), Opts :: list()) ->
    {ok, pid()}.
start_link(Ref, Socket, Transport, Opts) ->
    Pid = spawn_link(?MODULE, init, [Ref, Socket, Transport, Opts]),
    {ok, Pid}.

-spec init(Ref :: any(), Socket :: any(), Transport :: atom(), Opts :: list()) -> ok.
init(Ref, Socket, Transport, Opts) ->
    %% ack
    ok = ranch:accept_ack(Ref),
    %% get options
    ListenerPort = proplists:get_value(listener_port, Opts),
    Protocol = proplists:get_value(protocol, Opts),
    DispatcherModule = proplists:get_value(dispatcher_module, Opts),
    DispatcherOptions = proplists:get_value(dispatcher_options, Opts),
    %% build ref
    {ok, {IpAddressTerm, _Port}} = Transport:peername(Socket),
    ChannelId = ":" ++ integer_to_list(ListenerPort) ++ "{" ++ atom_to_list(Protocol) ++ "}" ++ inet:ntoa(IpAddressTerm),
    error_logger:info_msg("[IN|~s] Incoming erlgate channel connection", [ChannelId]),
    %% set options
    Transport:setopts(Socket, [binary, {packet, 4}]),
    %% get messages
    {OK, Closed, Error} = Transport:messages(),
    %% build state
    State = #state{
        transport = Transport,
        socket = Socket,
        channel_id = ChannelId,
        messages = {OK, Closed, Error},
        dispatcher_module = DispatcherModule,
        dispatcher_options = DispatcherOptions
    },
    %% enter loop
    recv_loop(State).

%% ===================================================================
%% Internal
%% ===================================================================
-spec recv_loop(#state{}) -> ok.
recv_loop(#state{
    transport = Transport,
    socket = Socket,
    channel_id = ChannelId,
    messages = {OK, Closed, Error}
} = State) ->
    Transport:setopts(Socket, [{active, once}]),
    receive
        {OK, Socket, Data} ->
            parse_request(Data, State);
        {Closed, Socket} ->
            error_logger:info_msg("[IN|~s] Got closed", [ChannelId]);
        {Error, Socket, Reason} ->
            error_logger:warning_msg("[IN|~s] Got error: ~p, closing socket", [ChannelId, Reason]),
            Transport:close(Socket)
    end.

-spec parse_request(Data :: binary(), #state{}) -> ok.
parse_request(Data, #state{
    transport = Transport,
    socket = Socket,
    channel_id = ChannelId
} = State) ->
    case catch binary_to_term(Data) of
        {'EXIT', {badarg, _}} ->
            error_logger:warning_msg("[IN|~s] Received an invalid request data: ~p, closing socket", [ChannelId, Data]),
            Transport:close(Socket);
        Message ->
            %% process message
            process_message(Message, State)
    end.

-spec process_message(Message :: any(), #state{}) -> ok.
process_message({call, Message}, State) ->
    Reply = call_dispatcher(handle_call, Message, State),
    send_reply(Reply, State),
    recv_loop(State);
process_message({cast, Message}, State) ->
    call_dispatcher(handle_cast, Message, State),
    recv_loop(State).

-spec call_dispatcher(Method :: atom(), Message :: any(), #state{}) -> Reply :: any().
call_dispatcher(Method, Message, #state{
    channel_id = ChannelId,
    dispatcher_module = DispatcherModule,
    dispatcher_options = DispatcherOptions
}) ->
    try DispatcherModule:Method(Message, DispatcherOptions) of
        Reply -> Reply
    catch Class:Reason ->
        Stacktrace = erlang:get_stacktrace(),
        erlang:Class([
            {reason, Reason},
            {channel_id, ChannelId},
            {original_call, Message},
            {stacktrace, Stacktrace}
        ])
    end.

-spec send_reply(Reply :: any(), #state{}) -> ok.
send_reply(Reply, #state{
    transport = Transport,
    socket = Socket
}) ->
    Data = term_to_binary(Reply),
    ok = Transport:send(Socket, Data).
