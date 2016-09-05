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
-module(erlgate).

%% API
-export([start/0, stop/0]).
-export([call/2, call/3]).

%% ===================================================================
%% API
%% ===================================================================
-spec start() -> ok.
start() ->
    ok = ensure_started(poolboy),
    ok = ensure_started(asn1),
    ok = ensure_started(crypto),
    ok = ensure_started(public_key),
    ok = ensure_started(ssl),
    ok = ensure_started(ranch),
    ok = ensure_started(erlgate).

-spec stop() -> ok.
stop() ->
    ok = application:stop(erlgate).

-spec call(ChannelRef :: atom(), Message :: any()) -> ok.
call(ChannelRef, Message) ->
    erlgate_out:call(ChannelRef, Message).

-spec call(ChannelRef :: atom(), Message :: any(), Timeout :: non_neg_integer() | infinity) -> ok.
call(ChannelRef, Message, Timeout) ->
    erlgate_out:call(ChannelRef, Message, Timeout).


%% ===================================================================
%% Private
%% ===================================================================
-spec ensure_started(App :: atom()) -> ok.
ensure_started(App) ->
    {ok, _} = application:ensure_all_started(App),
    ok.
