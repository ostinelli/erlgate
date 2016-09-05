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
-module(erlgate_app).
-behaviour(application).

%% API
-export([start/2, stop/1]).


%% ===================================================================
%% API
%% ===================================================================
-spec start(
    StartType :: normal | {takeover, node()} | {failover, node()},
    StartArgs :: any()
) -> {ok, pid()} | {ok, pid(), State :: any()} | {error, any()}.
start(_StartType, _StartArgs) ->
    %% start listeners
    erlgate_ranch:start_listener(),
    %% start sup
    erlgate_sup:start_link().

-spec stop(State :: any()) -> ok.
stop(_State) ->
    ok = erlgate_ranch:stop_listener().
