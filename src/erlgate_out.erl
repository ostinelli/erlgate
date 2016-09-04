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

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% records
-record(state, {
    host = "" :: string(),
    port = 0 :: non_neg_integer(),
    channel_id = "" :: string(),
    socket = undefined :: undefined | any(),
    timer_ref = undefined :: undefined | reference()
}).

%% macros
-define(RECONNECT_TIMEOUT_MS, 1000).
-define(RETRY_SLEEP_MS, 1000).
-define(RESPONSE_TIMEOUT, 5000).


%% ===================================================================
%% API
%% ===================================================================
-spec start_link(Args :: list()) -> {ok, pid()} | {error, any()}.
start_link(Args) ->
    gen_server:start_link(?MODULE, Args, []).

-spec call(Cluster :: atom(), Message :: any()) -> ok.
call(Cluster, Message) ->
    call(Cluster, Message, infinity).

-spec call(Cluster :: atom(), Message :: any(), RetryTimeout :: non_neg_integer() | infinity) -> ok.
call(Cluster, Message, RetryTimeout) ->
    poolboy:transaction(Cluster, fun(Worker) ->
        case gen_server:call(Worker, {call, Message}, 30000) of
            {error, _} when RetryTimeout =:= infinity ->
                timer:sleep(?RETRY_SLEEP_MS),
                call(Message, RetryTimeout);
            {error, _} when RetryTimeout > 0 ->
                timer:sleep(?RETRY_SLEEP_MS),
                call(Message, RetryTimeout - ?RETRY_SLEEP_MS);
            Result ->
                Result
        end
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
    %% build state
    State = #state{
        host = Host,
        port = Port,
        channel_id = ChannelId
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

handle_call(_, _From, #state{socket = undefined} = State) ->
    {reply, {error, no_socket}, State};

handle_call({call, Message}, _From, #state{
    channel_id = ChannelId,
    socket = Socket
} = State) ->
    Data = term_to_binary({call, Message}),
    case gen_tcp:send(Socket, Data) of
        ok ->
            %% receive reply
            case gen_tcp:recv(Socket, 0, ?RESPONSE_TIMEOUT) of
                {ok, ReplyData} ->
                    case catch binary_to_term(ReplyData) of
                        {'EXIT', {badarg, _}} ->
                            %% close socket
                            error_logger:warning_msg("Received invalid response data from channel OUT '~s': ~p", [ChannelId, ReplyData]),
                            State1 = timeout(State),
                            {reply, {error, erlgate_invalid_response_data}, State1};
                        Reply ->
                            {reply, Reply, State}
                    end
            end;
        {error, Reason} ->
            error_logger:warning_msg("Error while sending to channel OUT '~s' the call ~p: ~p", [ChannelId, Data, Reason]),
            State1 = timeout(State),
            {reply, {error, Reason}, State1}
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
terminate(_Reason, #state{socket = Socket}) ->
    %% terminate
    case Socket of
        undefined -> ok;
        _ -> ok = gen_tcp:close(Socket)
    end,
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
    port = Port
} = State) ->
    case gen_tcp:connect(Host, Port, [binary, {active, false}, {packet, 4}]) of
        {ok, Socket} ->
            error_logger:info_msg("Connected channel OUT '~s'", [ChannelId]),
            State#state{socket = Socket};
        {error, Reason} ->
            error_logger:error_msg("Error connecting channel OUT '~s': ~p, will try reconnecting in ~p ms", [
                ChannelId, Reason, ?RECONNECT_TIMEOUT_MS
            ]),
            State1 = State#state{socket = undefined},
            timeout(State1)
    end.

-spec timeout(#state{}) -> #state{}.
timeout(#state{
    timer_ref = TimerPrevRef
} = State) ->
    case TimerPrevRef of
        undefined -> ignore;
        _ -> erlang:cancel_timer(TimerPrevRef)
    end,
    TimerRef = erlang:send_after(?RECONNECT_TIMEOUT_MS, self(), connect),
    State#state{timer_ref = TimerRef}.
