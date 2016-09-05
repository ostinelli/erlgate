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
-module(erlgate_out_sup).
-behaviour(supervisor).

%% API
-export([start_link/0]).

%% supervisor callbacks
-export([init/1]).

%% include
-include("erlgate.hrl").


%% ===================================================================
%% API
%% ===================================================================
-spec start_link() -> {ok, pid()} | {already_started, pid()} | shutdown.
start_link() ->
    %% start supervisor
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Callbacks
%% ===================================================================
-spec init([]) ->
    {ok, {{supervisor:strategy(), non_neg_integer(), pos_integer()}, [supervisor:child_spec()]}}.
init([]) ->
    %% get databases
    Children = case erlgate_utils:get_env_value(channels_out) of
        {ok, ChannelsOutSpecs} ->
            children_spec(ChannelsOutSpecs);
        _ ->
            []
    end,
    %% start sup
    {ok, {{one_for_one, 10, 10}, Children}}.


%% ===================================================================
%% Internal
%% ===================================================================
-spec children_spec(ChannelsOutSpecs :: [channel_out_spec()]) -> [supervisor:child_spec()].
children_spec(ChannelsOutSpecs) ->
    children_spec(ChannelsOutSpecs, []).

-spec children_spec(ChannelsOutSpecs :: [channel_out_spec()], Specs :: [supervisor:child_spec()]) ->
    [supervisor:child_spec()].
children_spec([], Specs) -> Specs;
children_spec([{Ref, Host, Port, ConnectionNum, TransportSpec} | T], Specs) ->
    %% generate id
    ChannelId = atom_to_list(Ref) ++ "@" ++ Host ++ ":" ++ integer_to_list(Port),
    %% prepare args
    PoolArgs = [
        {name, {local, Ref}},
        {worker_module, erlgate_out},
        {size, ConnectionNum}
    ],
    ServerArgs = [
        {host, Host},
        {port, Port},
        {transport_spec, TransportSpec},
        {channel_id, ChannelId}
    ],
    %% generate spec
    SpecName = "erlgate_" ++ ChannelId,
    Spec = poolboy:child_spec(list_to_atom(SpecName), PoolArgs, ServerArgs),
    %% loop
    children_spec(T, [Spec | Specs]).
