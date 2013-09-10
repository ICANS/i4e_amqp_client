%% ====================================================================
%%
%% Copyright (c) ICANS GmbH, Valentinskamp 18, 20354 Hamburg/Germany and individual contributors.
%% All rights reserved.
%% 
%% Redistribution and use in source and binary forms, with or without modification,
%% are permitted provided that the following conditions are met:
%% 
%%     1. Redistributions of source code must retain the above copyright notice,
%%        this list of conditions and the following disclaimer.
%% 
%%     2. Redistributions in binary form must reproduce the above copyright
%%        notice, this list of conditions and the following disclaimer in the
%%        documentation and/or other materials provided with the distribution.
%% 
%%     3. Neither the name of ICANS GmbH nor the names of its contributors may be used
%%        to endorse or promote products derived from this software without
%%        specific prior written permission.
%% 
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
%% ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
%% WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
%% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
%% ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
%% (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
%% ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
%% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%% SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%%
%% ====================================================================
%%
%% @author Bjoern Kortuemm <bjoern.kortuemm@icans-gmbh.com>
%% @doc Tests basic application functionality.
%%
%% application_startup 
%% 
%% consume_base
%% consume_error
%%
%% @todo Test blocking/non_blocking



-module(basic_SUITE).

%% ====================================================================
%% API functions
%% ====================================================================
-export([groups/0,
         all/0,
         init_per_group/2,
         end_per_group/2,
         init_per_testcase/2,
         end_per_testcase/2]).
-export([application_startup/1,
		 consume_base/1, consume_error/1]).
-export([handle_deliver/1, handle_error/1]).

-define(APP, i4e_amqp_client).
-define(ETS, ?MODULE).
-define(WAIT_TIME, 500).
-define(GV(K,L), proplists:get_value(K,L)).

-include("../deps/amqp_client/include/amqp_client.hrl").
-include_lib("common_test/include/ct.hrl").

%% ====================================================================
%% Common Test Interface
%% ====================================================================
groups() ->
	[
	 {application, [], [application_startup]},
	 {consume, [sequence], [consume_base, consume_error]}
	].


all() ->
	[
	 {group, application},
	 {group, consume}
	].


init_per_group(_, Config) ->
	init_all(Config).


end_per_group(_, _Config) ->
	?APP:stop(),
	ok.


init_all(Config) ->
	?APP:start(),
	Config.


init_per_testcase(_, Config) ->
	?ETS = ets:new(?ETS, [named_table, public, set]),
	Config.


end_per_testcase(_, _Config) ->
	case ets:info(?ETS) of
		undefined -> ok;
		Info when is_list(Info) -> ets:delete(?ETS)
	end,
	ok.


%% ====================================================================
%% Tests
%% ====================================================================

%% ====================================================================
%% Test group application
%% ====================================================================
application_startup(_Config) ->
	Apps = application:which_applications(),
	case lists:keymember(?APP, 1, Apps) of
		true -> ok;
		false -> throw("Application not started")
	end,
	case i4e_amqp_client:which_consumers() of
		[] -> throw("No consumers running");
		_ -> ok
	end,
	case i4e_amqp_client:which_producers() of
		[] -> throw("No producers running");
		_ -> ok
	end,
	case i4e_amqp_client:which_setups() of
		[] -> throw("No setups running");
		_ -> ok
	end.

%% ====================================================================
%% Test group consume
%% ====================================================================
consume_base(_Config) ->
	Expected = erlang:list_to_binary(
				 lists:flatten(io_lib:fwrite("~p", [erlang:now()]))),
	consume_reset_actual(),
	i4e_amqp_client:produce(Expected),
	timer:sleep(?WAIT_TIME),
	consume_process_results(Expected, false).

consume_error(_Config) ->
	Expected = <<"error triggered">>,
	consume_reset_actual(),
	i4e_amqp_client:produce(<<"trigger error">>),
	timer:sleep(?WAIT_TIME),
	consume_process_results(Expected, true).

consume_reset_actual() ->
	ets:insert(?ETS, {actual, <<>>}),
	ets:insert(?ETS, {error_triggered, false}).

consume_process_results(Expected, ShouldTrigger) ->
	[{error_triggered, IsTriggered}] = ets:lookup(?ETS, error_triggered),
	[{actual, Actual}] = ets:lookup(?ETS, actual),
	case Actual of
		Expected -> ok;
		<<>> ->
			ct:pal(error, "No delivery after timeout of ~pms", [?WAIT_TIME]),
			throw(timeout);
		_ ->
			ct:pal(error, "Expected: ~p~nActual: ~p~n", [Expected, Actual]),
			throw(not_triggered)
	end,
	case IsTriggered of
		ShouldTrigger -> ok;
		true ->
			ct:pal(error, "Error triggered, but shouldn't have been"),
			throw(error_triggered);
		false ->
			ct:pal(error, "Error not triggered, but should have been"),
			throw(error_not_triggered)
	end.

%% ====================================================================
%% Test group produce
%% ====================================================================


%% ====================================================================
%% Consumer Callback
%% ====================================================================
handle_deliver(#amqp_msg{payload=Payload}=Msg) ->
	ct:pal("handle_deliver: ~p~n", [Msg]),
	case Payload of
		<<"trigger error">> ->
			ets:insert(?ETS, {actual, <<"error triggered">>}),
			{error, triggered};
		X ->
			ets:insert(?ETS, {actual, X}),
			ok
	end.

handle_error(X) ->
	ets:insert(?ETS, {error_triggered, true}),
	ct:pal("handle_error: ~p~n", [X]).

%% ====================================================================
%% Internal functions
%% ====================================================================

