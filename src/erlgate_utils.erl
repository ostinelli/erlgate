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
-module(erlgate_utils).

%% API
-export([get_env_value/1, get_env_value/2]).
-export([epoch_time/0]).
-export([clean_options/2]).


%% ===================================================================
%% API
%% ===================================================================
%% get an environment value
-spec get_env_value(Key :: any()) -> {ok, any()} | undefined.
get_env_value(Key) ->
    application:get_env(Key).

-spec get_env_value(Key :: any(), Default :: any()) -> {ok, any()}.
get_env_value(Key, Default) ->
    case application:get_env(Key) of
        undefined -> {ok, Default};
        {ok, Val} -> {ok, Val}
    end.

-spec epoch_time() -> non_neg_integer().
epoch_time() ->
    {M, S, _} = os:timestamp(),
    M * 1000000 + S.

-spec clean_options(Options :: [proplists:property()], [atom()]) -> [proplists:property()].
clean_options(Options, []) -> Options;
clean_options(Options, [Key | T]) ->
    case lists:member(Key, Options) of
        true ->
            Options1 = lists:delete(Key, Options),
            clean_options(Options1, T);
        false ->
            case lists:keymember(Key, 1, Options) of
                true ->
                    Options1 = lists:keydelete(Key, 1, Options),
                    clean_options(Options1, T);
                false ->
                    clean_options(Options, T)
            end
    end.
