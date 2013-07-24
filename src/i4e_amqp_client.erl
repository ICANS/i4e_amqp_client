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
%% @doc i4e_amqp_client control module.
%%
%% See function description for further information.


-module(i4e_amqp_client).

%% ====================================================================
%% Types
%% ====================================================================
-export_type([msg/0]).
-type msg() :: i4e_amqp_producer:msg().

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0, start/1, stop/0]).
-export([start_consumer/1, stop_consumer/1, which_consumers/0]).
-export([start_producer/1, stop_producer/1, which_producers/0]).
-export([produce/1, produce/2]).
-export([start_setup/1, stop_setup/1, which_setups/0]).


%% start/0
%% ====================================================================
%% @doc Start application with default environment
-spec start() -> ok.
%% ====================================================================
start() ->
	application:start(i4e_amqp_client).


%% start/1
%% ====================================================================
%% @doc Start application with custom environment
-spec start(Env :: [{term(), term()}]) -> ok.
%% ====================================================================
start(Env) ->
	application:load(i4e_amqp_client),
	lists:foreach(fun({K,V}) ->
						  application:set_env(K, V, i4e_amqp)
				  end, Env),
	application:start(i4e_amqp_client).


%% stop/0
%% ====================================================================
%% @doc Stop application
-spec stop() -> ok.
%% ====================================================================
stop() ->
	application:stop(i4e_amqp_client).


%% start_consumer/1
%% ====================================================================
%% @doc Start consumer
-spec start_consumer([i4e_amqp_consumer:start_opt()]) -> Result when
	Result :: {error, Reason}
			| {ok, pid()},
	Reason :: term().
%% ====================================================================
start_consumer(ConsumerDef) ->
	i4e_amqp_consumer_sup:start_consumer(ConsumerDef).


%% stop_consumer/1
%% ====================================================================
%% @doc Stop consumer
-spec stop_consumer(pid()) -> ok.
%% ====================================================================
stop_consumer(Pid) ->
	i4e_amqp_consumer:stop(Pid).


%% which_consumers/0
%% ====================================================================
%% @doc Get list of running consumers
-spec which_consumers() -> [pid()].
%% ====================================================================
which_consumers() ->
	i4e_amqp_consumer_sup:which_consumers().


%% start_producer/1
%% ====================================================================
%% @doc Start producer
-spec start_producer([i4e_amqp_producer:start_opt()]) -> Result when
	Result :: {error, Reason}
			| {ok, pid()},
	Reason :: term().
start_producer(ProducerDef) ->
	i4e_amqp_producer_sup:start_producer(ProducerDef).


%% stop_producer/1
%% ====================================================================
%% @doc Stop producer
-spec stop_producer(pid()) -> ok.
%% ====================================================================
stop_producer(Pid) ->
	i4e_amqp_producer:stop(Pid).


%% which_producers/0
%% ====================================================================
%% @doc Get list of running producers
-spec which_producers() -> [pid()].
%% ====================================================================
which_producers() ->
	i4e_amqp_producer_sup:which_producers().


%% produce/0
%% ====================================================================
%% @doc Produce message using the singleton producer (if configured)
-spec produce(Msg :: i4e_amqp_producer:msg()) -> ok.
%% ====================================================================
produce(Msg) ->
	i4e_amqp_producer:send(Msg).


%% produce/1
%% ====================================================================
%% @doc Produce message via producer identified by Ref
-spec produce(Ref :: i4e_amqp_producer:server_ref(), Msg :: i4e_amqp_producer:msg()) -> ok.
%% ====================================================================
produce(Ref, Msg) ->
	i4e_amqp_producer:send(Ref, Msg).


%% start_setup/1
%% ====================================================================
%% @doc Start setup
-spec start_setup(i4e_amqp_setup:start_opts()) -> Result when
	Result :: {error, Reason}
			| {ok, pid()},
	Reason :: term().
%% ====================================================================
start_setup(SetupDef) ->
	i4e_amqp_setup_sup:start_setup(SetupDef).


%% stop_setup/1
%% ====================================================================
%% @doc Stop setup
-spec stop_setup(pid()) -> ok.
%% ====================================================================
stop_setup(Pid) ->
	i4e_amqp_setup:stop(Pid).


%% which_setups/1
%% ====================================================================
%% @doc Get list of running setups
-spec which_setups() -> [pid()].
%% ====================================================================
which_setups() ->
	i4e_amqp_setup_sup:which_setups().


%% ====================================================================
%% Internal functions
%% ====================================================================


