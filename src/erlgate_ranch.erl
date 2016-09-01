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
-module(erlgate_ranch).

%% API
-export([start_listener/0]).

%% macros
-define(DEFAULT_ACCEPTOR_NUM, 10).


%% ===================================================================
%% API
%% ===================================================================
-spec start_listener() -> ok.
start_listener() ->
    %% get options
    {ok, Port} = erlgate_utils:get_env_value(port),
    {ok, Acceptors} = erlgate_utils:get_env_value(acceptors, ?DEFAULT_ACCEPTOR_NUM),
    {ok, DispatcherModule} = erlgate_utils:get_env_value(dispatcher_module),
    %% start ranch
    error_logger:info_msg("Starting ~p erlgate acceptors on port ~p", [Acceptors, Port]),
    {ok, _} = ranch:start_listener(
        erlgate_in, Acceptors, ranch_tcp, [
            {port, Port}
        ], erlgate_in, [
            {dispatcher_module, DispatcherModule}
        ]
    ),
    ok.
