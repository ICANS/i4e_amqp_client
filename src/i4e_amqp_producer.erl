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
%% @doc AMQP producer.
%%
%% In order to see how to use this, see:
%% * start_link/1 and type start_opt()
%% * send/1, send/2
%%
%% You should always properly shut down the producer using stop/1 or
%% you might end up with errors from amqp_client. 


-module(i4e_amqp_producer).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include_lib("amqp_client/include/amqp_client.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, stop/0, stop/1, send/1, send/2]).

-define(SERVER, ?MODULE).

-export_type([start_opt/0, server_ref/0, msg/0]).
-type start_opt() :: {server_ref, server_ref_opt()}
				   | {connection, i4e_amqp_util:connection_def()}
				   | {publish, [publish_opt()]}
				   | {delivery_mode, delivery_mode()}.
-type server_ref_opt() :: undefined
						| singleton
						| server_ref().
-type server_ref() :: atom()
					| {global, term()}.
-type publish_opt() :: {exchange, binary()}
					 | {queue, binary()}
					 | {routing_key, binary()}.
-type delivery_mode() :: persistent
					   | non_persistent
					   | undefined.
-type msg() :: #amqp_msg{}
			 | binary().

%% start_link/1
%% ====================================================================
%% @doc Start i4e_amqp_producer
%%
%% Use option {server_ref, Ref} to register the producer:
%% - undefined -> don't register (default)
%% - singleton -> register as locally default server
%% - {global, Ref} -> register globally
%% - Ref -> register locally
-spec start_link([start_opt()]) -> Result when
	Result :: {ok, pid()}
			| ignore
			| {error, Error},
	Error :: {already_started, pid()}
		   | term().
%% ====================================================================
start_link(Opts) ->
	case proplists:get_value(server_ref, Opts) of
		undefined -> gen_server:start_link(?MODULE, [Opts], []);
		singleton -> gen_server:start_link({local, ?SERVER}, ?MODULE, [Opts], []);
		{global, Ref} -> gen_server:start_link({global, Ref}, ?MODULE, [Opts], []);
		Ref -> gen_server:start_link({local, Ref}, ?MODULE, [Opts], [])
	end.


%% stop/0
%% ====================================================================
%% @doc Stop singleton producer
-spec stop() -> ok.
%% ====================================================================
stop() ->
	stop(?SERVER).


%% stop/1
%% ====================================================================
%% @doc Stop producer identified by Ref
-spec stop(server_ref()) -> ok.
%% ====================================================================
stop(Ref) ->
	gen_server:call(Ref, stop).


%% send/1
%% ====================================================================
%% @doc Send message via singleton producers
-spec send(Msg :: #amqp_msg{} | binary()) -> ok.
%% ====================================================================
send(Msg) ->
	send(?SERVER, Msg).


%% send/2
%% ====================================================================
%% @doc Send message via producer identified by Ref
-spec send(Ref :: server_ref(), Msg :: #amqp_msg{} | binary()) -> ok.
%% ====================================================================
send(Ref, #amqp_msg{}=Msg) ->
	gen_server:cast(Ref, {send, Msg});
send(Ref, Payload) when is_binary(Payload) ->
	send(Ref, #amqp_msg{payload=Payload}).


%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, { connection, channel, publish, delivery_mode, binding }).

%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:init-1">gen_server:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, State}
			| {ok, State, Timeout}
			| {ok, State, hibernate}
			| {stop, Reason :: term()}
			| ignore,
	State :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
init([Opts]) ->
	setup(Opts, #state{}).


%% handle_call/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_call-3">gen_server:handle_call/3</a>
-spec handle_call(Request :: term(), From :: {pid(), Tag :: term()}, State :: term()) -> Result when
	Result :: {reply, Reply, NewState}
			| {reply, Reply, NewState, Timeout}
			| {reply, Reply, NewState, hibernate}
			| {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason, Reply, NewState}
			| {stop, Reason, NewState},
	Reply :: term(),
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
handle_call(stop, _From, S) ->
	{stop, normal, ok, S};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.


%% handle_cast/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_cast-2">gen_server:handle_cast/2</a>
-spec handle_cast(Request :: term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_cast({send, Msg}, State) ->
	do_send(Msg, State),
	{noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.


%% handle_info/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_info-2">gen_server:handle_info/2</a>
-spec handle_info(Info :: timeout | term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_info(_Info, State) ->
    {noreply, State}.


%% terminate/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:terminate-2">gen_server:terminate/2</a>
-spec terminate(Reason, State :: term()) -> Any :: term() when
	Reason :: normal
			| shutdown
			| {shutdown, term()}
			| term().
%% ====================================================================
terminate(_Reason, S) ->
	shutdown(S),
    ok.


%% code_change/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:code_change-3">gen_server:code_change/3</a>
-spec code_change(OldVsn, State :: term(), Extra :: term()) -> Result when
	Result :: {ok, NewState :: term()} | {error, Reason :: term()},
	OldVsn :: Vsn | {down, Vsn},
	Vsn :: term().
%% ====================================================================
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% ====================================================================
%% Internal functions
%% ====================================================================
-define(GV(K,L), proplists:get_value(K,L)).
-define(GV(K,L,D), proplists:get_value(K,L,D)).
-define(GB(K,L), proplists:get_bool(K,L)).

%% setup/2
%% ====================================================================
%% @doc Setup producer
%%
%% Open connection, open channel, bind (opt), define production function
-spec setup([start_opt()], #state{}) -> {ok, #state{}}.
%% ====================================================================
setup(Opts, S) ->
	ConnectionDef = i4e_amqp_util:connection(?GV(connection, Opts)),
	{ok, Conn} = amqp_connection:start(ConnectionDef),
	{ok, Channel} = amqp_connection:open_channel(Conn),
	link(Channel),
	PublishOpts = ?GV(publish, Opts),
	{Binding, Publish} = case proplists:is_defined(exchange, PublishOpts) of
							 true -> get_publish(exchange, PublishOpts, Channel);
							 false -> get_publish(queue, PublishOpts, Channel)
						 end,
	{ok, S#state{
				 connection = Conn,
				 channel = Channel,
				 publish = Publish,
				 binding = Binding,
				 delivery_mode = delivery_mode(?GV(delivery_mode, Opts))
				 }}.



%% shutdown/1
%% ====================================================================
%% @doc Shutdown producer
-spec shutdown(#state{}) -> {ok, #state{}}.
%% ====================================================================
shutdown(#state{ binding = Binding, channel = Channel, connection = Conn }=S) ->
	case Binding of
		undefined -> ok;
		#'queue.bind'{ queue = Q, exchange = E, routing_key = R} ->
			amqp_channel:call(Channel, #'queue.unbind'{
													   queue = Q,
													   exchange = E,
													   routing_key = R})
	end,
	amqp_channel:close(Channel),
	amqp_connection:close(Conn),
	{ok, S#state{ binding = undefined, channel = undefined, connection = undefined}}.


%% get_publish/1
%% ====================================================================
%% @doc Get publish
-spec get_publish(Type, Def, Channel :: pid()) -> #'basic.publish'{} when
	Type :: queue
		  | exchange,
	Def :: i4e_amqp_util:queue_def()
		 | i4e_amqp_util:exchange_def().
%% ====================================================================
get_publish(queue, Opts, Channel) ->
	Queue = i4e_amqp_util:queue(Opts),
	case ?GB(declare, Opts) of
		true -> amqp_channel:call(Channel, Queue);
		false -> ok
	end,
	{undefined, #'basic.publish'{
								 exchange = <<>>,
								 routing_key = Queue#'queue.declare'.queue}};
get_publish(exchange, Opts, Channel) ->
	RoutingKey = ?GV(routing_key, Opts, <<>>),
	Exchange = i4e_amqp_util:exchange(Opts),
	case ?GB(declare, Opts) of
		true -> amqp_channel:call(Channel, Exchange);
		false -> ok
	end,
	Binding = case ?GV(binding, Opts) of
				  undefined -> undefined;
				  L ->
					  QD = i4e_amqp_util:queue(?GV(queue, L)),
					  #'queue.declare_ok'{} = amqp_channel:call(Channel, QD),
					  {ok, B} = bind(QD, Exchange, ?GV(routing_key, L, <<>>), Channel),
					  case ?GB(unbind_on_stop, L) of
						  true -> B;
						  false -> undefined
					  end
			  end,
	{Binding, #'basic.publish'{exchange = Exchange#'exchange.declare'.exchange,
							   routing_key = RoutingKey}}.


bind(Queue, Exchange, RoutingKey, Channel) ->
	Binding = #'queue.bind'{
							queue = Queue,
							exchange = Exchange,
							routing_key = RoutingKey},
	#'queue.bind_ok'{} = amqp_channel:call(
						   Channel, 
						   Binding),
	{ok, Binding}.


%% delivery_mode/1
%% ====================================================================
%% @doc Get internal delivery_mode representation
-spec delivery_mode(undefined | non_persistent | persistent) -> term().
%% ====================================================================
delivery_mode(undefined) ->	undefined;
delivery_mode(non_persistent) -> undefined;
delivery_mode(persistent) -> 2.


%% do_send/2
%% ====================================================================
%% @doc Send message to broker
-spec do_send(#amqp_msg{}, #state{}) -> ok.
%% ====================================================================
do_send(#amqp_msg{props=MProps}=Msg,
		#state{publish=Publish, channel=Channel, delivery_mode=SDM}) ->
	Props = case MProps#'P_basic'.delivery_mode of
				undefined -> #'P_basic'{delivery_mode=SDM};
				DM -> DM
			end,
	amqp_channel:cast(Channel, Publish, Msg#amqp_msg{props=Props}).

