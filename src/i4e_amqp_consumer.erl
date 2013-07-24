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
%% @doc Simple consumer server.
%%
%% Start the consumer with start_link/1.
%% You have to provide a processor definition, which is a tuple of type
%% and start options. 
%%
%% You should always properly shut down the consumer using stop/1 or
%% you might end up with errors from amqp_client. 


-module(i4e_amqp_consumer).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include_lib("amqp_client/include/amqp_client.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([start_opts/0, start_opt/0]).
-type start_opts() :: [start_opt()].
-type start_opt() :: {connection, i4e_amqp_util:connection_def()}
				   | {queue, i4e_amqp_util:queue_def()}
				   | {processor, processor_def()}.
-type processor_def() :: {callback, [i4e_amqp_callback_processor:start_opt()]}
					   | {module(), term()}.

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, stop/1]).


%% start_link/1
%% ====================================================================
%% @doc start linked consumer
%%
%% Will connect, open channel, subscribe
-spec start_link(start_opts()) -> Result when
	Result :: {ok, pid()}
			| ignore
			| {error, Error},
	Error :: {already_started, pid()}
		   | term().
%% ====================================================================
start_link(Opts) ->
	gen_server:start_link(?MODULE, [Opts], []).


%% stop/1
%% ====================================================================
%% @doc stop consumer identified by Ref
-spec stop(Ref :: pid()) -> ok.
%% ====================================================================
stop(Ref) ->
	gen_server:call(Ref, stop).


%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, {channel, connection, consumer_tag, processor_def}).

-define(GV(K,L), proplists:get_value(K,L)).
-define(GV(K,L,D), proplists:get_value(K,L,D)).

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
	ConnDef = i4e_amqp_util:connection(?GV(connection, Opts)),
	QueueDef = i4e_amqp_util:queue(?GV(queue, Opts)),
	ProcessorDef = get_amqp_gen_consumer_def(?GV(processor, Opts)),
	setup(ConnDef, QueueDef, ProcessorDef, #state{}).


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
terminate(_Reason, State) ->
	shutdown(State),
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

%% setup/1
%% ====================================================================
%% @doc Setup consumer
%%
%% Open connection, open channel, add consumer, start consumption
-spec setup(ConnDef, #'queue.declare'{}, processor_def(), #state{}) -> {ok, #state{}} when
	ConnDef :: #amqp_params_network{}
			 | #amqp_params_direct{}.
%% ====================================================================
setup(ConnDef, QueueDef, ProcessorDef, S) ->
	{ok, Conn} = amqp_connection:start(ConnDef),
	{ok, Channel} = amqp_connection:open_channel(Conn, ProcessorDef),
	link(Channel),
	ok = amqp_channel:call_consumer(Channel, {set_channel, Channel}),
	#'queue.declare_ok'{queue=Q} = amqp_channel:call(Channel, QueueDef),
	#'basic.consume_ok'{consumer_tag = Tag} = amqp_channel:call(Channel, #'basic.consume'{queue=Q}), 
	{ok, S#state{
				 channel = Channel,
				 connection = Conn,
				 processor_def = ProcessorDef,
				 consumer_tag = Tag}}.


%% shutdown/1
%% ====================================================================
%% @doc Shutdown consumer
-spec shutdown(#state{}) -> {ok, #state{}}.
%% ====================================================================
shutdown(#state{channel=Ch, connection=Conn}=S) ->
	amqp_channel:close(Ch),
	amqp_connection:close(Conn),
	{ok, S#state{
				 connection = undefined,
				 channel = undefined}}.


%% get_amqp_gen_consumer_def/1
%% ====================================================================
%% @doc Get consumer definition to be used in amqp_connection:open_channel/2
-spec get_amqp_gen_consumer_def
		({callback, [any()]}) -> {i4e_amqp_callback_processor, [[any()]]};
		({gen_consumer, [Opt]}) -> {module(), list()} when
	Opt :: {module, module()}
		 | {args, list()}.
%% ====================================================================
get_amqp_gen_consumer_def({callback, Opts}) ->
	true = i4e_amqp_callback_processor:is_valid_opts(Opts),
	{i4e_amqp_callback_processor, [Opts]};
get_amqp_gen_consumer_def({gen_consumer, Opts}) ->
	Mod = ?GV(module, Opts),
	Args = ?GV(args, Opts),
	if
		is_list(Args) -> {Mod, Args};
		true -> throw({"Arguments must be a list", Args})
	end.
