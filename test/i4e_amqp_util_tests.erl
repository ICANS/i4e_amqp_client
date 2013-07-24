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
%% @doc Unit test for i4e_amqp_util.


-module(i4e_amqp_util_tests).

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("eunit/include/eunit.hrl").

connection_def_test_() ->
	Host = "1.2.3.4",
	Port = 1234,
	VirtualHost = <<"virtual_host">>,
	Username = <<"username">>,
	Password = <<"password">>,
	Opts = [
			{host, Host},
			{port, Port},
			{virtual_host, VirtualHost},
			{username, Username},
			{password, Password} ],
	AP = #amqp_params_network{
			host = Host,
			port = Port,
			virtual_host = VirtualHost,
			username = Username,
			password = Password},
	DAP = #amqp_params_direct{},
	[
	 ?_assertEqual(AP, i4e_amqp_util:connection(AP)),
	 ?_assertEqual(AP, i4e_amqp_util:connection(Opts)),
	 ?_assertEqual(DAP, i4e_amqp_util:connection(DAP))
	].


queue_def_test_() ->
	Queue = <<"queue">>,
	Durable = true,
	Args = [<<"some arg">>],
	Opts = [
			{queue, Queue},
			{durable, Durable},
			{arguments, Args} ],
	QD = #'queue.declare'{
						  queue = Queue,
						  durable = Durable,
						  arguments = Args},
	[
	 ?_assertEqual(QD, i4e_amqp_util:queue(QD)),
	 ?_assertEqual(QD, i4e_amqp_util:queue(Opts)),
	 ?_assertEqual(#'queue.declare'{queue=Queue},
				   i4e_amqp_util:queue([{queue, Queue}]))
	].


exchange_def_test_() ->
	Exchange = <<"exchange">>,
	Durable = true,
	Type = <<"fanout">>,
	Opts = [
			{exchange, Exchange},
			{durable, Durable},
			{type, Type}],
	ED = #'exchange.declare'{
							 exchange = Exchange,
							 durable = Durable,
							 type = Type },
	[
	 ?_assertEqual(ED, i4e_amqp_util:exchange(ED)),
	 ?_assertEqual(ED, i4e_amqp_util:exchange(Opts)),
	 ?_assertEqual(#'exchange.declare'{exchange=Exchange},
				   i4e_amqp_util:exchange([{exchange, Exchange}]))
	].
%% ====================================================================
%% Internal functions
%% ====================================================================


