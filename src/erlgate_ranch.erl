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

%% specs
-type channel_in_spec() :: {ListenerPort :: non_neg_integer(), DispatcherModule :: atom()}.


%% ===================================================================
%% API
%% ===================================================================
-spec start_listener() -> ok.
start_listener() ->
    %% get options
    case erlgate_utils:get_env_value(channels_in) of
        {ok, ChannelsInSpec} ->
            start_channels_in(ChannelsInSpec);
        undefined ->
            error_logger:info_msg("Starting erlgate without channels in (none specified)")
    end.


%% ===================================================================
%% Internal
%% ===================================================================
-spec start_channels_in([channel_in_spec()]) -> ok.
start_channels_in([]) -> ok;
start_channels_in([{ListenerPort, DispatcherModule} | T]) ->
    Acceptors = ?DEFAULT_ACCEPTOR_NUM,
    error_logger:info_msg("Starting ~p erlgate acceptors on port ~p", [Acceptors, ListenerPort]),
    %% start ranch
    Ref = list_to_atom(lists:concat(["erlgate_in_", integer_to_list(ListenerPort)])),
    {ok, _} = ranch:start_listener(Ref, Acceptors, ranch_tcp,
        [{port, ListenerPort}],
        erlgate_in,
        [{dispatcher_module, DispatcherModule}]
    ),
    %% loop
    start_channels_in(T).