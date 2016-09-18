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
-module(erlgate_channel_connection_SUITE).

%% callbacks
-export([all/0]).
-export([init_per_suite/1, end_per_suite/1]).
-export([groups/0, init_per_group/2, end_per_group/2]).
-export([init_per_testcase/2, end_per_testcase/2]).

%% tests
-export([
    channel_in_invalid_opening/1,
    channel_in_invalid_channel_signature/1,
    channel_in_unsupported_version/1,
    channel_in_outside_time_range/1,
    channel_in_invalid_signature/1,
    channel_in_valid_signature/1
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
        {group, channels_in}
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
        {channels_in, [shuffle], [
            channel_in_invalid_opening,
            channel_in_invalid_channel_signature,
            channel_in_unsupported_version,
            channel_in_outside_time_range,
            channel_in_invalid_signature,
            channel_in_valid_signature
        ]}
    ].

%% -------------------------------------------------------------------
%% Function: init_per_suite(Config0) ->
%%				Config1 | {skip,Reason} |
%%              {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% -------------------------------------------------------------------
init_per_suite(Config) -> Config.

%% -------------------------------------------------------------------
%% Function: end_per_suite(Config0) -> void() | {save_config,Config1}
%% Config0 = Config1 = [tuple()]
%% -------------------------------------------------------------------
end_per_suite(_Config) -> ok.

%% -------------------------------------------------------------------
%% Function: init_per_group(GroupName, Config0) ->
%%				Config1 | {skip,Reason} |
%%              {skip_and_save,Reason,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% -------------------------------------------------------------------
init_per_group(_GroupName, Config) ->
    %% set variables
    application:set_env(erlgate, channels_in, [{8900, "pass-for-8900", erlgate_test_dispatcher, [], tcp}]),
    %% start
    ok = erlgate:start(),
    %% return
    Config.

%% -------------------------------------------------------------------
%% Function: end_per_group(GroupName, Config0) ->
%%				void() | {save_config,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% -------------------------------------------------------------------
end_per_group(_GroupName, _Config) ->
    %% stop
    ok = erlgate:stop().

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
channel_in_invalid_opening(_Config) ->
    %% connect
    {ok, Socket} = gen_tcp:connect("localhost", 8900, [binary, {active, once}, {packet, 4}]),
    %% send invalid data
    gen_tcp:send(Socket, <<1, 2, 3, 4, 5>>),
    ReplyData = receive
        {tcp, Socket, ReplyData0} ->
            ReplyData0
    after 1000 ->
            ok = no_response_received
    end,
    <<1>> = ReplyData,
    (catch gen_tcp:close(Socket)).

channel_in_invalid_channel_signature(_Config) ->
    %% connect
    {ok, Socket} = gen_tcp:connect("localhost", 8900, [binary, {active, once}, {packet, 4}]),
    %% send invalid channel signature
    gen_tcp:send(Socket,
        <<
            0, 234, 169, 56, 0, 22, 7, 15, 0, 1,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        >>
    ),
    ReplyData = receive
        {tcp, Socket, ReplyData0} ->
            ReplyData0
    after 1000 ->
            ok = no_response_received
    end,
    <<2>> = ReplyData,
    (catch gen_tcp:close(Socket)).

channel_in_unsupported_version(_Config) ->
    %% connect
    {ok, Socket} = gen_tcp:connect("localhost", 8900, [binary, {active, once}, {packet, 4}]),
    %% send invalid version
    gen_tcp:send(Socket,
        <<
            1, 234, 169, 56, 0, 22, 7, 15, 0, 2,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        >>
    ),
    ReplyData = receive
        {tcp, Socket, ReplyData0} ->
            ReplyData0
    after 1000 ->
            ok = no_response_received
    end,
    <<2>> = ReplyData,
    (catch gen_tcp:close(Socket)).

channel_in_outside_time_range(_Config) ->
    %% connect
    {ok, Socket} = gen_tcp:connect("localhost", 8900, [binary, {active, once}, {packet, 4}]),
    %% send invalid time
    Version = 1,
    Epoch = 1474284242,
    Data = <<
        1, 234, 169, 56, 0, 22, 7, 15,
        Version:16/integer,
        Epoch:32/integer,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    >>,
    gen_tcp:send(Socket, Data),
    ReplyData = receive
        {tcp, Socket, ReplyData0} ->
            ReplyData0
    after 1000 ->
            ok = no_response_received
    end,
    <<3>> = ReplyData,
    (catch gen_tcp:close(Socket)).

channel_in_invalid_signature(_Config) ->
    %% connect
    {ok, Socket} = gen_tcp:connect("localhost", 8900, [binary, {active, once}, {packet, 4}]),
    %% send invalid time
    Version = 1,
    Epoch = erlgate_utils:epoch_time(),
    Data = <<
        1, 234, 169, 56, 0, 22, 7, 15,
        Version:16/integer,
        Epoch:32/integer,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    >>,
    gen_tcp:send(Socket, Data),
    ReplyData = receive
        {tcp, Socket, ReplyData0} ->
            ReplyData0
    after 1000 ->
            ok = no_response_received
    end,
    <<4>> = ReplyData,
    (catch gen_tcp:close(Socket)).

channel_in_valid_signature(_Config) ->
    %% connect
    {ok, Socket} = gen_tcp:connect("localhost", 8900, [binary, {active, once}, {packet, 4}]),
    %% send invalid time
    Version = 1,
    Epoch = erlgate_utils:epoch_time(),
    Signature = crypto:hmac(sha256, "pass-for-8900", integer_to_binary(Epoch)),
    Data = <<
        1, 234, 169, 56, 0, 22, 7, 15,
        Version:16/integer,
        Epoch:32/integer,
        Signature:32/binary
    >>,
    gen_tcp:send(Socket, Data),
    ReplyData = receive
        {tcp, Socket, ReplyData0} ->
            ReplyData0
    after 1000 ->
            ok = no_response_received
    end,
    <<0>> = ReplyData,
    (catch gen_tcp:close(Socket)).
