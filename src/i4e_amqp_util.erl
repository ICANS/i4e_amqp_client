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
%% @doc Util module providing types and converters.
%%
%% See functions for further information.


-module(i4e_amqp_util).

-include_lib("amqp_client/include/amqp_client.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([connection_def/0,
			  queue_def/0, queue_declare/0,
			  exchange_def/0, exchange_declare/0,
			  binding_def/0, binding_declare/0]).
-type connection_def() :: #amqp_params_network{}
						| #amqp_params_direct{}
						| [connection_opt()].
-type connection_opt() :: {host, string()}
						| {port, pos_integer()}
						| {virtual_host, binary()}
						| {username, binary()}
						| {password, binary()}.
-type queue_def() :: queue_declare()
				   | [queue_opt()].
-type queue_declare() :: #'queue.declare'{}.
-type queue_opt() :: {queue, binary()}
				   | {durable, boolean()}
				   | {arguments, [any()]}.
-type exchange_def() :: #'exchange.declare'{}
					  | [exchange_opt()].
-type exchange_opt() :: {exchange, binary()}
					  | {durable, boolean()}
					  | {type, atom()}
					  | {arguments, [any()]}.
-type exchange_declare() :: #'exchange.declare'{}.
-type binding_def() :: #'queue.bind'{}
					 | [binding_opt()].
-type binding_opt() :: {queue, binary()}
					 | {exchange, binary()}
					 | {routing_key, binary()}.
-type binding_declare() :: #'queue.bind'{}.

%% ====================================================================
%% API functions
%% ====================================================================
-export([connection/1, queue/1, exchange/1, binding/1]).
-export([amqp_msg/1]).

-define(GV(K,L), proplists:get_value(K,L)).
-define(GV(K,L,D), proplists:get_value(K,L,D)).

%% connection/1
%% ====================================================================
%% @doc Get connection declaration to be used with amqp_client
-spec connection(connection_def()) -> #amqp_params_direct{} | #amqp_params_network{}.
%% ====================================================================
connection(#amqp_params_network{}=AP) ->
	AP;
connection(#amqp_params_direct{}=AP) ->
	AP;
connection(O) when is_list(O) ->
	#amqp_params_network{
						 host = ?GV(host, O),
						 port = ?GV(port, O),
						 virtual_host = ?GV(virtual_host, O),
						 username = ?GV(username, O),
						 password = ?GV(password, O)}.


%% queue/1
%% ====================================================================
%% @doc Get queue declaratin to be used with amqp_client
-spec queue(queue_def()) -> queue_declare().
%% ====================================================================
queue(#'queue.declare'{}=Q) ->
	Q;
queue(O) when is_list(O) ->
	#'queue.declare'{ durable = DD, arguments = DA } = #'queue.declare'{},
	#'queue.declare'{
					 queue = ?GV(queue, O),
					 durable = ?GV(durable, O, DD),
					 arguments = ?GV(arguments, O, DA)}.


%% exchange/1
%% ====================================================================
%% @doc Get exchange declaration to be used with amqp_client
-spec exchange(exchange_def()) -> exchange_declare().
%% ====================================================================
exchange(#'exchange.declare'{}=E) ->
	E;
exchange(O) when is_list(O) ->
	#'exchange.declare'{ durable = DD, type = DT, arguments = DA } = #'exchange.declare'{},
	#'exchange.declare'{
						exchange = ?GV(exchange, O),
						durable = ?GV(durable, O, DD),
						type = ?GV(type, O, DT),
						arguments = ?GV(arguments, O, DA)}.


%% binding/1
%% ====================================================================
%% @doc Get binding declaration to be used with amqp_client
-spec binding(binding_def()) -> binding_declare().
%% ====================================================================
binding(#'queue.bind'{}=B) ->
	B;
binding(Opts) ->
	#'queue.bind'{
				  queue = ?GV(queue, Opts),
				  exchange = ?GV(exchange, Opts),
				  routing_key = ?GV(routing_key, Opts, <<>>)}.


%% amqp_msg/1
%% ====================================================================
%% @doc Get amqp_msg{} with Payload
-spec amqp_msg(Payload :: binary() | list()) -> #amqp_msg{}.
%% ====================================================================
amqp_msg(Payload) when is_binary(Payload) ->
	#amqp_msg{payload = Payload};
amqp_msg(Payload) when is_list(Payload) ->
	amqp_msg(erlang:list_to_binary(Payload)).




