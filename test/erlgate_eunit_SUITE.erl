-module(erlgate_eunit_SUITE).

%% API
-export([all/0]).

%% tests
-export([
    utils_eunit/1
]).

%% includes
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
        utils_eunit
    ].

%% ===================================================================
%% Tests
%% ===================================================================
utils_eunit(_Config) ->
    ok = eunit:test(erlgate_utils_test).
