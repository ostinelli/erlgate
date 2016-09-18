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
-module(erlgate_test_dispatcher).
-behaviour(erlgate_dispatcher).

%% Callbacks
-export([init/1]).
-export([handle_call/2]).
-export([handle_cast/2]).

%% records
-record(state, {
    with_options = false :: boolean(),
    raise_error = false :: boolean(),
    timeout = false :: boolean()
}).


init(Options) ->
    {ok, #state{
        with_options = lists:member(with_options, Options),
        raise_error = lists:member(raise_error, Options),
        timeout = lists:member(timeout, Options)
    }}.

handle_call(Message, State) ->
    if
        State#state.with_options =:= true ->
            {reply, {called_with_options, Message}, State};
        State#state.raise_error =:= true ->
            exit(blow_up);
        State#state.timeout =:= true ->
            {noreply, State};
        true ->
            {reply, {received, Message}, State}
    end.

handle_cast(Message, State) ->
    global:send(erlgate_SUITE_result, {received, Message}),
    {noreply, State}.
