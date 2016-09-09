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
-module(erlgate_in_ranch).

%% API
-export([start_listeners/0]).
-export([stop_listeners/0]).

%% macros
-define(DEFAULT_ACCEPTOR_NUM, 10).

%% include
-include("erlgate.hrl").


%% ===================================================================
%% API
%% ===================================================================
-spec start_listeners() -> ok.
start_listeners() ->
    %% get options
    case erlgate_utils:get_env_value(channels_in) of
        {ok, ChannelsInSpec} ->
            start_channels_in(ChannelsInSpec);
        undefined ->
            error_logger:info_msg("Starting erlgate without channels in (none specified)")
    end.

-spec stop_listeners() -> ok.
stop_listeners() ->
    %% get options
    case erlgate_utils:get_env_value(channels_in) of
        {ok, ChannelsInSpec} ->
            stop_channels_in(ChannelsInSpec);
        undefined ->
            ok
    end.

%% ===================================================================
%% Internal
%% ===================================================================
-spec start_channels_in([channel_in_spec()]) -> ok.
start_channels_in([]) -> ok;
start_channels_in([{ListenerPort, ChannelPassword, DispatcherModule, DispatcherOptions, tcp} | T]) ->
    error_logger:info_msg("Starting ~p erlgate TCP acceptors on port ~p", [?DEFAULT_ACCEPTOR_NUM, ListenerPort]),
    %% start channel
    start_channel_in(ListenerPort, ChannelPassword, DispatcherModule, DispatcherOptions, ranch_tcp, tcp, []),
    %% loop
    start_channels_in(T);
start_channels_in([{ListenerPort, ChannelPassword, DispatcherModule, DispatcherOptions, {ssl, SslOptions}} | T]) ->
    error_logger:info_msg("Starting ~p erlgate SSL acceptors on port ~p", [?DEFAULT_ACCEPTOR_NUM, ListenerPort]),
    %% start channel
    start_channel_in(ListenerPort, ChannelPassword, DispatcherModule, DispatcherOptions, ranch_ssl, ssl, SslOptions),
    %% loop
    start_channels_in(T).

-spec start_channel_in(
    ListenerPort :: non_neg_integer(),
    ChannelPassword :: string(),
    DispatcherModule :: atom(),
    DispatcherOptions :: [any()],
    RanchProtocol :: ranch_tcp | ranch_ssl,
    Protocol :: tcp | ssl,
    ProtoOptions :: [ssl:ssl_option()]
) -> {ok, any()}.
start_channel_in(ListenerPort, ChannelPassword, DispatcherModule, DispatcherOptions, RanchProtocol, Protocol, ProtoOptions) ->
    %% start ranch
    Ref = ref(ListenerPort),
    {ok, _} = ranch:start_listener(Ref, ?DEFAULT_ACCEPTOR_NUM, RanchProtocol,
        [
            {port, ListenerPort}
        ] ++ ProtoOptions,
        erlgate_in,
        [
            {protocol, Protocol},
            {listener_port, ListenerPort},
            {channel_password, ChannelPassword},
            {dispatcher_module, DispatcherModule},
            {dispatcher_options, DispatcherOptions}
        ]
    ).

-spec stop_channels_in([channel_in_spec()]) -> ok.
stop_channels_in([]) -> ok;
stop_channels_in([{ListenerPort, _, _, _, _} | T]) ->
    error_logger:info_msg("Stopping erlgate acceptors on port ~p", [ListenerPort]),
    Ref = ref(ListenerPort),
    ranch:stop_listener(Ref),
    %% loop
    stop_channels_in(T).

-spec ref(ListenerPort :: non_neg_integer()) -> atom().
ref(ListenerPort) ->
    list_to_atom(lists:concat(["erlgate_in_", integer_to_list(ListenerPort)])).
