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
-module(erlgate_out).
-behaviour(gen_server).
-behaviour(poolboy_worker).

%% API
-export([start_link/1]).
-export([call/2, call/3]).
-export([cast/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% macros
-define(DEFAULT_RECONNECT_TIMEOUT_MS, 1000).
-define(DEFAULT_RESPONSE_TIMEOUT, 30000).

%% include
-include("erlgate.hrl").

%% records
-record(state, {
    host = "" :: string(),
    port = 0 :: non_neg_integer(),
    channel_id = "" :: string(),
    socket = undefined :: undefined | any(),
    timer_ref = undefined :: undefined | reference(),
    transport = gen_tcp :: gen_tcp | ssl,
    transport_options = [] :: [ssl:ssl_option()]
}).


%% ===================================================================
%% API
%% ===================================================================
-spec start_link(Args :: list()) -> {ok, pid()} | {error, any()}.
start_link(Args) ->
    gen_server:start_link(?MODULE, Args, []).

-spec call(ChannelRef :: atom(), Message :: any()) -> Reply :: any().
call(ChannelRef, Message) ->
    call(ChannelRef, Message, ?DEFAULT_RESPONSE_TIMEOUT).

-spec call(ChannelRef :: atom(), Message :: any(), Timeout :: non_neg_integer() | infinity) -> Reply :: any().
call(ChannelRef, Message, Timeout) ->
    poolboy:transaction(ChannelRef, fun(Worker) ->
        case gen_server:call(Worker, {call, Message, Timeout}) of
            {ok, Reply} ->
                Reply;
            {error, Reason} ->
                exit({Reason, {original_call, {ChannelRef, Message}}})
        end
    end).

-spec cast(ChannelRef :: atom(), Message :: any()) -> ok.
cast(ChannelRef, Message) ->
    poolboy:transaction(ChannelRef, fun(Worker) ->
        gen_server:cast(Worker, {cast, Message})
    end).

%% ===================================================================
%% Callbacks
%% ===================================================================

%% ----------------------------------------------------------------------------------------------------------
%% Init
%% ----------------------------------------------------------------------------------------------------------
-spec init(Args :: list()) ->
    {ok, #state{}} |
    {ok, #state{}, Timeout :: non_neg_integer()} |
    ignore |
    {stop, Reason :: any()}.
init(Args) ->
    %% read options
    Host = proplists:get_value(host, Args),
    Port = proplists:get_value(port, Args),
    ChannelId = proplists:get_value(channel_id, Args),
    {Transport, TransportOptions} = case proplists:get_value(transport_spec, Args) of
        tcp -> {gen_tcp, []};
        {ssl, SslOptions} -> {ssl, SslOptions}
    end,
    %% build state
    State = #state{
        host = Host,
        port = Port,
        channel_id = ChannelId,
        transport = Transport,
        transport_options = TransportOptions
    },
    %% connect
    State1 = connect(State),
    %% return
    {ok, State1}.

%% ----------------------------------------------------------------------------------------------------------
%% Call messages
%% ----------------------------------------------------------------------------------------------------------
-spec handle_call(Request :: any(), From :: any(), #state{}) ->
    {reply, Reply :: any(), #state{}} |
    {reply, Reply :: any(), #state{}, Timeout :: non_neg_integer()} |
    {noreply, #state{}} |
    {noreply, #state{}, Timeout :: non_neg_integer()} |
    {stop, Reason :: any(), Reply :: any(), #state{}} |
    {stop, Reason :: any(), #state{}}.

handle_call(_, _From, #state{
    channel_id = ChannelId,
    socket = undefined
} = State) ->
    {reply, {error, {no_channel_out_socket, {channel_id, ChannelId}}}, State};

handle_call({call, Message, Timeout}, _From, #state{
    channel_id = ChannelId,
    transport = Transport,
    socket = Socket
} = State) ->
    Data = term_to_binary({call, Message}),
    case Transport:send(Socket, Data) of
        ok ->
            %% receive reply
            case Transport:recv(Socket, 0, Timeout) of
                {ok, ReplyData} ->
                    case catch binary_to_term(ReplyData) of
                        {'EXIT', {badarg, _}} ->
                            %% close socket
                            error_logger:error_msg("[OUT|~s] Received invalid response data: ~p", [ChannelId, ReplyData]),
                            {stop, erlgate_invalid_response_data, {error, erlgate_invalid_response_data}, State};
                        Reply ->
                            {reply, {ok, Reply}, State}
                    end;
                {error, Reason} ->
                    error_logger:error_msg("[OUT|~s] Error while waiting response to the call ~p: ~p", [ChannelId, Message, Reason]),
                    {stop, Reason, {error, Reason}, State}
            end;
        {error, Reason} ->
            error_logger:error_msg("[OUT|~s] Error while sending the call ~p: ~p", [ChannelId, Message, Reason]),
            {stop, Reason, {error, Reason}, State}
    end;

handle_call(Request, From, State) ->
    error_logger:warning_msg("Received from ~p an unknown call message: ~p", [Request, From]),
    {reply, undefined, State}.

%% ----------------------------------------------------------------------------------------------------------
%% Cast messages
%% ----------------------------------------------------------------------------------------------------------
-spec handle_cast(Msg :: any(), #state{}) ->
    {noreply, #state{}} |
    {noreply, #state{}, Timeout :: non_neg_integer()} |
    {stop, Reason :: any(), #state{}}.

handle_cast(_, #state{socket = undefined} = State) ->
    {noreply, State};

handle_cast({cast, Message}, #state{
    channel_id = ChannelId,
    transport = Transport,
    socket = Socket
} = State) ->
    Data = term_to_binary({cast, Message}),
    case Transport:send(Socket, Data) of
        ok ->
            {noreply, State};
        {error, Reason} ->
            error_logger:error_msg("[OUT|~s] Error while sending the cast ~p: ~p", [ChannelId, Message, Reason]),
            {stop, Reason, State}
    end;

handle_cast(Msg, State) ->
    error_logger:warning_msg("Received an unknown cast message: ~p", [Msg]),
    {noreply, State}.

%% ----------------------------------------------------------------------------------------------------------
%% All non Call / Cast messages
%% ----------------------------------------------------------------------------------------------------------
-spec handle_info(Info :: any(), #state{}) ->
    {noreply, #state{}} |
    {noreply, #state{}, Timeout :: non_neg_integer()} |
    {stop, Reason :: any(), #state{}}.

handle_info(connect, State) ->
    State1 = connect(State),
    {noreply, State1};

handle_info(Info, State) ->
    error_logger:warning_msg("Received an unknown info message: ~p", [Info]),
    {noreply, State}.

%% ----------------------------------------------------------------------------------------------------------
%% Terminate
%% ----------------------------------------------------------------------------------------------------------
-spec terminate(Reason :: any(), #state{}) -> terminated.
terminate(_Reason, State) ->
    disconnect(State),
    terminated.

%% ----------------------------------------------------------------------------------------------------------
%% Convert process state when code is changed.
%% ----------------------------------------------------------------------------------------------------------
-spec code_change(OldVsn :: any(), #state{}, Extra :: any()) -> {ok, #state{}}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% ===================================================================
%% Internal
%% ===================================================================
-spec connect(#state{}) -> #state{}.
connect(#state{
    channel_id = ChannelId,
    host = Host,
    port = Port,
    transport = Transport,
    transport_options = TransportOptions
} = State) ->
    %% disconnect if necessary
    State1 = disconnect(State),
    %% build options
    Options = erlgate_utils:clean_options(TransportOptions, [binary, active, packet]) ++ [binary, {active, false}, {packet, 4}],
    %% connect
    case Transport:connect(Host, Port, Options) of
        {ok, Socket} ->
            error_logger:info_msg("[OUT|~s] Connected", [ChannelId]),
            State1#state{socket = Socket};
        {error, Reason} ->
            error_logger:error_msg("[OUT|~s] Error connecting: ~p, will try reconnecting in ~p ms", [
                ChannelId, Reason, ?DEFAULT_RECONNECT_TIMEOUT_MS
            ]),
            timeout(State1)
    end.

-spec disconnect(#state{}) -> #state{}.
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
    error_logger:info_msg("[OUT|~s] Disconnected", [ChannelId]),
    State#state{socket = undefined}.

-spec timeout(#state{}) -> #state{}.
timeout(#state{
    timer_ref = TimerPrevRef
} = State) ->
    case TimerPrevRef of
        undefined -> ignore;
        _ -> erlang:cancel_timer(TimerPrevRef)
    end,
    TimerRef = erlang:send_after(?DEFAULT_RECONNECT_TIMEOUT_MS, self(), connect),
    State#state{timer_ref = TimerRef}.
