-module(erlgate_utils_test).
-include_lib("eunit/include/eunit.hrl").


%% ===================================================================
%% Tests
%% ===================================================================
clean_options_test_() ->
    Tests = [
        {
            {[{one, 1}, {two, 2}, three], []},
            [{one, 1}, {two, 2}, three]
        },
        {
            {[{one, 1}, {two, 2}, three], [one]},
            [{two, 2}, three]
        },
        {
            {[{one, 1}, {two, 2}, three], [three]},
            [{one, 1}, {two, 2}]
        },
        {
            {[{one, 1}, {two, 2}, three], [two, three]},
            [{one, 1}]
        },
        {
            {[{one, 1}, {two, 2}, three], [one, two, three]},
            []
        }
    ],
    [?_assertEqual(Expected, erlgate_utils:clean_options(Options, Keys)) || {{Options, Keys}, Expected} <- Tests].
