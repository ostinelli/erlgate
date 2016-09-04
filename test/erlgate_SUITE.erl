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
-module(erlgate_SUITE).

%% callbacks
-export([all/0]).
-export([init_per_suite/1, end_per_suite/1]).
-export([groups/0, init_per_group/2, end_per_group/2]).
-export([init_per_testcase/2, end_per_testcase/2]).

%% tests
-export([
    call_one_way/1,
    call_one_way_with_timeout/1,
    call_both_ways/1
]).

%% include
-include_lib("common_test/include/ct.hrl").


%% ===================================================================
%% Callbacks
%% ===================================================================

%% -------------------------------------------------------------------
%% Function: all() -> GroupsAndTestCases | {skip,Reason}
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%% TestCase = atom()
%% Reason = term()
%% -------------------------------------------------------------------
all() ->
    [
        {group, end_to_end}
    ].

%% -------------------------------------------------------------------
%% Function: groups() -> [Group]
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%% Shuffle = shuffle | {shuffle,{integer(),integer(),integer()}}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%			   repeat_until_any_ok | repeat_until_any_fail
%% N = integer() | forever
%% -------------------------------------------------------------------
groups() ->
    [
        {end_to_end, [shuffle], [
            call_one_way,
            call_one_way_with_timeout,
            call_both_ways
        ]}
    ].
%% -------------------------------------------------------------------
%% Function: init_per_suite(Config0) ->
%%				Config1 | {skip,Reason} |
%%              {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% -------------------------------------------------------------------
init_per_suite(Config) ->
    %% init
    SlaveNodeShortName = erlgate_slave,
    %% start slave
    {ok, SlaveNode} = erlgate_test_suite_helper:start_slave(SlaveNodeShortName),
    %% config
    [
        {slave_node_short_name, SlaveNodeShortName},
        {slave_node, SlaveNode}
        | Config
    ].

%% -------------------------------------------------------------------
%% Function: end_per_suite(Config0) -> void() | {save_config,Config1}
%% Config0 = Config1 = [tuple()]
%% -------------------------------------------------------------------
end_per_suite(Config) ->
    %% get slave node name
    SlaveNodeShortName = proplists:get_value(slave_node_short_name, Config),
    %% stop slave
    erlgate_test_suite_helper:stop_slave(SlaveNodeShortName).

%% -------------------------------------------------------------------
%% Function: init_per_group(GroupName, Config0) ->
%%				Config1 | {skip,Reason} |
%%              {skip_and_save,Reason,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% -------------------------------------------------------------------
init_per_group(_GroupName, Config) -> Config.

%% -------------------------------------------------------------------
%% Function: end_per_group(GroupName, Config0) ->
%%				void() | {save_config,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% -------------------------------------------------------------------
end_per_group(_GroupName, _Config) -> ok.

% ----------------------------------------------------------------------------------------------------------
% Function: init_per_testcase(TestCase, Config0) ->
%				Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
% TestCase = atom()
% Config0 = Config1 = [tuple()]
% Reason = term()
% ----------------------------------------------------------------------------------------------------------
init_per_testcase(_TestCase, Config) -> Config.

% ----------------------------------------------------------------------------------------------------------
% Function: end_per_testcase(TestCase, Config0) ->
%				void() | {save_config,Config1} | {fail,Reason}
% TestCase = atom()
% Config0 = Config1 = [tuple()]
% Reason = term()
% ----------------------------------------------------------------------------------------------------------
end_per_testcase(_TestCase, _Config) -> ok.

%% ===================================================================
%% Tests
%% ===================================================================
call_one_way(Config) ->
    %% get slave
    SlaveNode = proplists:get_value(slave_node, Config),
    %% set variables
    erlgate_test_suite_helper:set_environment_variables(node(), main),
    erlgate_test_suite_helper:set_environment_variables(SlaveNode, slave),
    ok = application:unset_env(erlgate, channels_in),
    ok = rpc:call(SlaveNode, application, unset_env, [erlgate, channels_out]),
    %% start
    ok = erlgate:start(),
    ok = rpc:call(SlaveNode, erlgate, start, []),
    %% wait for connection
    timer:sleep(1500),
    %% call from local to remote and get response back
    {received, <<"my test message">>} = erlgate:call(node_1, <<"my test message">>),
    {received_from_2, <<"my other test message">>} = erlgate:call(node_2, <<"my other test message">>).

call_one_way_with_timeout(Config) ->
    %% get slave
    SlaveNode = proplists:get_value(slave_node, Config),
    %% set variables
    erlgate_test_suite_helper:set_environment_variables(node(), main),
    erlgate_test_suite_helper:set_environment_variables(SlaveNode, slave),
    ok = application:unset_env(erlgate, channels_in),
    ok = rpc:call(SlaveNode, application, unset_env, [erlgate, channels_out]),
    %% start
    ok = erlgate:start(),
    ok = rpc:call(SlaveNode, erlgate, start, []),
    %% wait for connection
    timer:sleep(1500),
    %% call from local to remote and timeout
    Result = (catch erlgate:call(node_1, <<"my test message">>, 100)),
    {'EXIT', {timeout, {original_call, {node_1, <<"my test message">>}}}} = Result,
    %% wait for gen_server up
    timer:sleep(500).

call_both_ways(Config) ->
    %% get slave
    SlaveNode = proplists:get_value(slave_node, Config),
    %% set variables
    erlgate_test_suite_helper:set_environment_variables(node(), main),
    erlgate_test_suite_helper:set_environment_variables(SlaveNode, slave),
    %% start
    ok = erlgate:start(),
    ok = rpc:call(SlaveNode, erlgate, start, []),
    %% wait for connection
    timer:sleep(1500),
    %% call from local to remote and get response back
    {received, <<"my test message">>} = erlgate:call(node_1, <<"my test message">>),
    {received_from_2, <<"my other test message">>} = erlgate:call(node_2, <<"my other test message">>),
    %% call from remote to local and get response back
    {received, <<"my test message from remote">>} = rpc:call(SlaveNode, erlgate, call, [node_3, <<"my test message from remote">>]),
    {received_from_2, <<"my other test message from remote">>} = rpc:call(SlaveNode, erlgate, call, [node_4, <<"my other test message from remote">>]).
