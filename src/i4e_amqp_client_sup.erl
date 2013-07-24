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
%% @doc Root supervisor of i4e_amqp_client application.
%%
%% start_link/1 starts all setups, consumers and producers that are
%% defined in the application configuration using their supervisors.
%% Setups will be started before consumers and producers are started
%% so all needed entities are set up before trying to use them.
%% 
%% stop/0 stops all setups, consumers and producers.
%% Stop them actively or you might end up getting errors from the
%% amqp_client and none of the setups will tear down the changes
%% they made.


-module(i4e_amqp_client_sup).
-behaviour(supervisor).
-export([init/1]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, stop/0]).

-define(SERVER, ?MODULE).

%% start_link/0
%% ====================================================================
%% @doc Start named supervisor
-spec start_link([Opt]) -> Result when
	Opt :: {consumers, [any()]},
	Result :: {ok, pid()}
			| ignore
			| {error, Error},
	Error :: {already_started, pid()}
			| shutdown
			| term().
%% ====================================================================
start_link(Opts) ->
	%% I have to start the sups sequentially in this order, otherwise
	%% setup would not be finished when consumers and producers start.
	%% If you have a better solution I'd be glad to know it :)
	case supervisor:start_link({local, ?SERVER}, ?MODULE, []) of
		{ok, Pid} ->
			{ok, _} = start_setup_sup(Pid, Opts),
			{ok, _} = start_consumer_sup(Pid, Opts),
			{ok, _} = start_producer_sup(Pid, Opts),
			{ok, Pid};
		X ->
			X
	end.
	

%% start_setup_sup/2
%% ====================================================================
%% @doc Start setup supervisor
-spec start_setup_sup(Ref, Opts) -> supervisor:startchild_ret() when
	Ref :: pid(),
	Opts :: [i4e_amqp_setup:start_opts()]. %% A list of proplists
%% ====================================================================
start_setup_sup(Ref, Opts) ->
	Setups = proplists:get_value(setups, Opts, []),
	SetupSup = {i4e_amqp_setup, {i4e_amqp_setup_sup, start_link, [Setups]},
				   permanent, 2000, supervisor, [i4e_amqp_setup]},
	supervisor:start_child(Ref, SetupSup).


%% start_consumer_sup/2
%% ====================================================================
%% @doc Start consumer supervisor
-spec start_consumer_sup(Ref, Opts) -> supervisor:startchild_ret() when
	Ref :: pid(),
	Opts :: [i4e_amqp_consumer:start_opts()]. %% A list of proplists
%% ====================================================================
start_consumer_sup(Ref, Opts) ->
	Consumers = proplists:get_value(consumers, Opts, []),
	ConsumerSup = {i4e_amqp_consumer_sup, {i4e_amqp_consumer_sup, start_link, [Consumers]},
				   permanent, 10000, supervisor, [i4e_amqp_consumer_sup]},
	supervisor:start_child(Ref, ConsumerSup).
	

%% start_producer_sup/2
%% ====================================================================
%% @doc Start producer supervisor
-spec start_producer_sup(Ref, Opts) -> supervisor:startchild_ret() when
	Ref :: pid(),
	Opts :: [i4e_amqp_producer:start_opts()]. % A list of proplists
%% ====================================================================
start_producer_sup(Ref, Opts) ->
	Producers = proplists:get_value(producers, Opts, []),
	ProducerSup = {i4e_ampq_producer_sup, {i4e_amqp_producer_sup, start_link, [Producers]},
				   permanent, 10000, supervisor, [i4e_amqp_producer_sup]},
	supervisor:start_child(Ref, ProducerSup).


%% stop/0
%% ====================================================================
%% @doc Stop setups, producers, consumers
-spec stop() -> ok.
%% ====================================================================
stop() ->
	i4e_amqp_producer_sup:stop_producers(),
	i4e_amqp_consumer_sup:stop_consumers(),
	i4e_amqp_setup_sup:stop_setups(),
	ok.


%% ====================================================================
%% Behavioural functions 
%% ====================================================================

%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/supervisor.html#Module:init-1">supervisor:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, {SupervisionPolicy, [ChildSpec]}} | ignore,
	SupervisionPolicy :: {RestartStrategy, MaxR :: non_neg_integer(), MaxT :: pos_integer()},
	RestartStrategy :: one_for_all
					 | one_for_one
					 | rest_for_one
					 | simple_one_for_one,
	ChildSpec :: {Id :: term(), StartFunc, RestartPolicy, Type :: worker | supervisor, Modules},
	StartFunc :: {M :: module(), F :: atom(), A :: [term()] | undefined},
	RestartPolicy :: permanent
				   | transient
				   | temporary,
	Modules :: [module()] | dynamic.
%% ====================================================================
init([]) ->
    {ok,{ {one_for_one,1,1}, []}}.


%% ====================================================================
%% Internal functions
%% ====================================================================


