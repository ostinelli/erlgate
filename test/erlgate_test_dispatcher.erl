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
-export([handle_call/2]).
-export([handle_cast/2]).

%% TODO: should we use {reply, Message} formats?
-spec handle_call(Message :: any, Options :: any()) -> any().
handle_call(Message, Options) ->
    WithOptions = lists:member(with_options, Options),
    RaiseError = lists:member(raise_error, Options),
    if
        WithOptions =:= true ->
            {called_with_options, Message};
        RaiseError =:= true ->
            exit(blow_up);
        true ->
            timer:sleep(200),
            {received, Message}
    end.

handle_cast(Message, _Options) ->
    global:send(erlgate_SUITE_result, {received, Message}).
