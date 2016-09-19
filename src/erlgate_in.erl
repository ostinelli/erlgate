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

%% macros
-define(DEFAULT_SIGNATURE_RECV_TIMEOUT_MS, 30000).
-define(DEFAULT_ACCEPTED_DATE_RANGE_SEC, 600).

%% records
-record(state, {
    transport = undefined :: atom(),
    socket = undefined :: any(),
    channel_id = "" :: string(),
    channel_password = <<>> :: binary(),
    messages = undefined :: any(),
    dispatcher_module = undefined :: any(),
    dispatcher_options = undefined :: any(),
    dispatcher_state = undefined :: any()
}).

%% include
-include("erlgate.hrl").


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
    Protocol = proplists:get_value(protocol, Opts),
    ListenerPort = proplists:get_value(listener_port, Opts),
    ChannelPassword = list_to_binary(proplists:get_value(channel_password, Opts)),
    DispatcherModule = proplists:get_value(dispatcher_module, Opts),
    DispatcherOptions = proplists:get_value(dispatcher_options, Opts),
    %% build ref
    {ok, {IpAddressTerm, _Port}} = Transport:peername(Socket),
    ChannelId = ":" ++ integer_to_list(ListenerPort) ++ "{" ++ atom_to_list(Protocol) ++ "}" ++ inet:ntoa(IpAddressTerm),
    error_logger:info_msg("[IN|~s] Connected, waiting for signature", [ChannelId]),
    %% set options
    Transport:setopts(Socket, [binary, {packet, 4}]),
    %% get messages
    {OK, Closed, Error} = Transport:messages(),
    %% build state
    State = #state{
        transport = Transport,
        socket = Socket,
        channel_id = ChannelId,
        channel_password = ChannelPassword,
        messages = {OK, Closed, Error},
        dispatcher_module = DispatcherModule,
        dispatcher_options = DispatcherOptions
    },
    %% verify
    receive_channel_signature_data(State).

%% ===================================================================
%% Internal
%% ===================================================================
-spec receive_channel_signature_data(#state{}) -> ok.
receive_channel_signature_data(#state{
    channel_id = ChannelId,
    transport = Transport,
    socket = Socket
} = State) ->
    case Transport:recv(Socket, 0, ?DEFAULT_SIGNATURE_RECV_TIMEOUT_MS) of
        {ok, <<
            ProtocolSignature:8/binary,
            Version:16/integer,
            Epoch:32/integer,
            Signature:32/binary
        >>} ->
            check_version(ProtocolSignature, Version, Epoch, Signature, State);
        {ok, InvalidData} ->
            error_logger:error_msg("[IN|~s] Invalid channel opening data received: ~p, closing socket", [ChannelId, InvalidData]),
            Transport:send(Socket, <<1>>),
            disconnect(State);
        {error, Reason} ->
            error_logger:error_msg("[IN|~s] Error while getting signature data: ~p, closing socket", [ChannelId, Reason]),
            disconnect(State)
    end.

-spec check_version(
    ProtocolSignature :: binary(),
    Version :: integer(),
    Epoch :: non_neg_integer(),
    Signature :: binary(),
    #state{}
) -> ok.
check_version(?PROTOCOL_SIGNATURE, 1, Epoch, Signature, State) ->
    verify_date_range(Epoch, Signature, State);
check_version(_, Version, _, _, #state{
    channel_id = ChannelId,
    transport = Transport,
    socket = Socket
} = State) ->
    error_logger:error_msg("[IN|~s] Unsupported channel signature or version (~p), closing socket", [ChannelId, Version]),
    Transport:send(Socket, <<2>>),
    disconnect(State).

-spec verify_date_range(
    Epoch :: non_neg_integer(),
    Signature :: binary(),
    #state{}
) -> ok.
verify_date_range(Epoch, Signature, #state{
    channel_id = ChannelId,
    transport = Transport,
    socket = Socket
} = State) ->
    EpochOnServer = erlgate_utils:epoch_time(),
    case abs(EpochOnServer - Epoch) =< ?DEFAULT_ACCEPTED_DATE_RANGE_SEC of
        true ->
            verify_channel_signature(Epoch, Signature, State);
        false ->
            error_logger:error_msg("[IN|~s] Epoch ~p outside of accepted range (on server: ~p), closing socket", [ChannelId, Epoch, EpochOnServer]),
            Transport:send(Socket, <<3>>),
            disconnect(State)
    end.

-spec verify_channel_signature(
    Epoch :: non_neg_integer(),
    Signature :: binary(),
    #state{}
) -> ok.
verify_channel_signature(Epoch, Signature, #state{
    channel_id = ChannelId,
    transport = Transport,
    socket = Socket,
    channel_password = ChannelPassword
} = State) ->
    ComputedSignature = crypto:hmac(sha256, ChannelPassword, integer_to_binary(Epoch)),
    case ComputedSignature of
        Signature ->
            dispatcher_init(State);
        _ ->
            error_logger:error_msg("[IN|~s] Invalid signature, closing socket", [ChannelId]),
            Transport:send(Socket, <<4>>),
            disconnect(State)
    end.

-spec dispatcher_init(#state{}) -> ok.
dispatcher_init(#state{
    channel_id = ChannelId,
    dispatcher_module = DispatcherModule,
    dispatcher_options = DispatcherOptions
} = State) ->
    DispatcherState = try DispatcherModule:init(DispatcherOptions) of
        {ok, DispatcherState0} -> DispatcherState0
    catch Class:Reason ->
        Stacktrace = erlang:get_stacktrace(),
        erlang:Class([
            {reason, Reason},
            {channel_id, ChannelId},
            {dispatcher_init_options, DispatcherOptions},
            {stacktrace, Stacktrace}
        ])
    end,
    ack_ok(State#state{dispatcher_state = DispatcherState}).

-spec ack_ok(#state{}) -> ok.
ack_ok(#state{
    channel_id = ChannelId,
    transport = Transport,
    socket = Socket
} = State) ->
    Transport:send(Socket, <<0>>),
    error_logger:info_msg("[IN|~s] Connection successful", [ChannelId]),
    recv_loop(State).

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
            disconnect(State)
    end.

-spec parse_request(Data :: binary(), #state{}) -> ok.
parse_request(Data, #state{
    channel_id = ChannelId
} = State) ->
    case catch binary_to_term(Data) of
        {'EXIT', {badarg, _}} ->
            error_logger:warning_msg("[IN|~s] Received an invalid request data: ~p, closing socket", [ChannelId, Data]),
            disconnect(State);
        Message ->
            %% process message
            process_message(Message, State)
    end.

-spec process_message(Message :: any(), #state{}) -> ok.
process_message({call, Message}, State) ->
    case call_dispatcher(handle_call, Message, State) of
        {reply, Reply, NewDispatcherState} ->
            send_reply(Reply, State),
            recv_loop(State#state{dispatcher_state = NewDispatcherState});
        {noreply, NewDispatcherState} ->
            recv_loop(State#state{dispatcher_state = NewDispatcherState})
    end;
process_message({cast, Message}, State) ->
    {noreply, NewDispatcherState} = call_dispatcher(handle_cast, Message, State),
    recv_loop(State#state{dispatcher_state = NewDispatcherState}).

-spec call_dispatcher(Method :: atom(), Message :: any(), #state{}) -> Reply :: any().
call_dispatcher(Method, Message, #state{
    channel_id = ChannelId,
    dispatcher_module = DispatcherModule,
    dispatcher_state = DispatcherState
}) ->
    try DispatcherModule:Method(Message, DispatcherState) of
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

-spec disconnect(#state{}) -> ok.
disconnect(#state{
    socket = Socket
} = State) when Socket =:= undefined ->
    State;
disconnect(#state{
    channel_id = ChannelId,
    transport = Transport,
    socket = Socket
} = State) ->
    Transport:close(Socket),
    error_logger:info_msg("[IN|~s] Disconnected", [ChannelId]).
