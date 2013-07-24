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
%% @doc Setup server.
%%
%% To see how to use this, see:
%% * start_link/1 and type start_opts()
%% * stop/1
%%
%% You should always properly shut down the setup using stop/1 or
%% you might end up with errors from amqp_client and tear down will
%% not take place.


-module(i4e_amqp_setup).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include_lib("amqp_client/include/amqp_client.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([start_opts/0]).
-type start_opts() :: [start_opt()].
-type start_opt() :: {queue, i4e_amqp_util:queue_def()}
				   | {exchange, i4e_amqp_util:exchange_def()}
				   | {binding, i4e_amqp_util:binding_def()}
				   | {teardown_on_stop, [teardown_opt()]}.
-type teardown_opt() :: all
					  | all_bindings
					  | i4e_amqp_util:queue_def()
					  | i4e_amqp_util:exchange_def()
					  | i4e_amqp_util:binding_def().



%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, stop/1]).

%% start_link/1
%% ====================================================================
%% @doc Start unnamed, linked setup server.
%%
%% Will declare entities to the broker according to given options.
%% See type start_opt() or itest/config/ct.config.template for further
%% information.
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
%% @doc Stop server
%%
%% Will tear down entities it has declared according to the 
%% teardown_on_stop start option. See README.md for further information.
-spec stop(pid()) -> ok.
%% ====================================================================
stop(Ref) ->
	gen_server:call(Ref, stop).


%% declare/2
%% ====================================================================
%% doc Declare queue, exchange or binding dynamically.
%%
%% Will be torn down on stop according to teardown_on_stop option
%%-spec declare(Ref, Def) -> ...
%% @todo implement i4e_amqp_setup:declare/2
%declare(Ref, Def) ->
%	gen_server:call(Ref, {declare, Def}).


%% delete/2
%% ====================================================================
%% doc Delete queue, exchange or binding dynamically
%%-spec delete(Ref, Def) -> ...
%% @todo implement i4e_amqp_setup:delete/2
%delete(Ref, Def) ->
%	gen_server:call(Ref, {delete, Def}).

%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, { channel, connection, declarations, teardown }).

-define(GV(K,L), proplists:get_value(K,L)). 
-define(GV(K,L,D), proplists:get_value(K,L,D)).
-define(GA(K,L), proplists:get_all_values(K, L)).
-define(GB(K,L), proplists:get_bool(K,L)).

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
	teardown(State),
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

%% setup/2
%% ====================================================================
%% @doc Setup environment
-spec setup([Def], #state{}) -> {ok, #state{}} when
	Def :: i4e_amqp_util:queue_def()
		 | i4e_amqp_util:exchange_def()
		 | i4e_amqp_util:binding_def().
%% ====================================================================
setup(Opts, S) ->
	{ok, Conn} = amqp_connection:start(i4e_amqp_util:connection(?GV(connection, Opts))),
	{ok, Ch} = amqp_connection:open_channel(Conn),
	link(Ch),
	Declarations = declare_list(Ch, queue, ?GA(queue, Opts)) ++
					   declare_list(Ch, exchange, ?GA(exchange, Opts)) ++
					   declare_list(Ch, binding, ?GA(binding, Opts)),
	{ok, S#state{
				 connection = Conn,
				 channel = Ch,
				 declarations = Declarations,
				 teardown = get_teardown_list(Opts, Declarations)}}.


%% shutdown/1
%% ====================================================================
%% @doc Shutdown channel and conneciton
-spec shutdown(#state{}) -> {ok, #state{}}.
%% ====================================================================
shutdown(#state{channel=Ch, connection=Conn}=S) ->
	amqp_channel:close(Ch),
	amqp_connection:close(Conn),
	{ok, S#state{
				 connection = undefined,
				 channel = undefined}}.


%% get_teardown_list/2
%% ====================================================================
%% @doc Get teardown list from given declarations and options.
-spec get_teardown_list(start_opts(), [Declaration]) -> TeardownList when
	Declaration :: #'queue.bind'{}
				 | #'exchange.declare'{}
				 | #'queue.declare'{},
	TeardownList :: [TDDeclaration],
	TDDeclaration :: Declaration
				   | #'queue.delete'{}
				   | #'exchange.delete'{}
				   | #'queue.unbind'{}.
%% ====================================================================
get_teardown_list(Opts, Declarations) ->
	TD = ?GV(teardown_on_stop, Opts, []),
	case ?GB(all, TD) of
		false -> case ?GB(all_bindings, TD) of
					 false -> get_decs(TD);
					 true -> filter_bindings(
							   Declarations,
							   get_decs(proplists:delete(all_bindings, TD)))
				 end;
		true -> lists:reverse(Declarations) ++ get_decs(proplists:delete(all, TD))
	end.	


%% filter_bindings/2
%% ====================================================================
%% @doc Add all bindings from list of declarations (parameter 1) to
%% given list A (parameter 2).
-spec filter_bindings(list(), list()) -> list().
%% ====================================================================
filter_bindings([], A) ->
	A;
filter_bindings([#'queue.bind'{}=H|T], A) ->
	filter_bindings(T, [H|A]);
filter_bindings([_|T], A) ->
	filter_bindings(T, A).


%% teardown/1
%% ====================================================================
%% @doc Tear down all entities that are marked to be torn down.
-spec teardown(#state{}) -> ok.
%% ====================================================================
teardown(#state{channel = Ch, teardown = Td}) ->
	lists:foreach(fun(X) ->
						  amqp_channel:call(Ch, teardown_declare(X))
				  end, Td),
	ok.


%% get_decs/1
%% ====================================================================
%% @doc Get declarations from a list of definitions / declarations.
%%
%% See i4e_amqp_util for further information.
-spec get_decs(list()) -> list().
%% ====================================================================
get_decs(X) ->	[get_dec(E) || E <- X].

%% get_dec
%% ====================================================================
%% @doc Get declaration from given definition / declaration.
%%
%% See i4e_amqp_util for further information.
-spec get_dec({queue, i4e_amqp_util:queue_def()}) ->
								i4e_amqp_util:queue_declare();
			({exchange, i4e_amqp_util:exchange_def()}) ->
								i4e_amqp_util:exchange_declare();
			({binding, i4e_amqp_util:binding_def()}) ->
								i4e_amqp_util:binding_declare().
%% ====================================================================
get_dec({queue, Q}) ->		i4e_amqp_util:queue(Q);
get_dec({exchange, E}) ->	i4e_amqp_util:exchange(E);
get_dec({binding, B}) ->	i4e_amqp_util:binding(B).


%% teardown_declare/1
%% ====================================================================
%% @doc Get teardown declaration according to given setup declaration
%% or teardown declaration
-spec teardown_declare(SetupDeclaration) -> TeardownDeclaration when
	SetupDeclaration :: i4e_amqp_util:queue_declare()
					  | i4e_amqp_util:exchange_declare()
					  | i4e_amqp_util:binding_declare()
					  | #'queue.unbind'{}
					  | #'exchange.delete'{}
					  | #'queue.delete'{},
	TeardownDeclaration :: #'queue.unbind'{}
						 | #'exchange.delete'{}
						 | #'queue.delete'{}.
teardown_declare(#'queue.bind'{queue = Q, exchange = E, routing_key = R, arguments = A}) ->
	#'queue.unbind'{queue = Q, exchange = E, routing_key = R, arguments = A};
teardown_declare(#'exchange.declare'{exchange = E}) ->
	#'exchange.delete'{exchange = E};
teardown_declare(#'queue.declare'{queue = Q}) ->
	#'queue.delete'{queue = Q};
teardown_declare(#'queue.unbind'{}=B) ->
	B;
teardown_declare(#'exchange.delete'{}=E) ->
	E;
teardown_declare(#'queue.delete'{}=Q) ->
	Q.
	

%% declare_list/3
%% ====================================================================
%% @doc Declare list of type T (queues, exchanger or bindings) to channel Ch
-spec declare_list(Channel :: pid(), Type, [Def]) -> [Declare] when
	Type :: queue
		  | exchange
		  | binding,
	Def :: i4e_amqp_util:queue_def()
		 | i4e_amqp_util:exchange_def()
		 | i4e_amqp_util:binding_def(),
	Declare :: i4e_amqp_util:queue_declare()
			 | i4e_amqp_util:exchange_declare()
			 | i4e_amqp_util:binding_declare().
%% ====================================================================
declare_list(Ch, T, L) ->
	[declare(Ch, T, E) || E <- L].


%% declare/3
%% ====================================================================
%% @doc Declare queue, exchange or binding to channel Ch
-spec declare(Channel :: pid(), Type, Def) -> Declare when
	Type :: queue
		  | exchange
		  | binding,
	Def :: i4e_amqp_util:queue_def()
		 | i4e_amqp_util:exchange_def()
		 | i4e_amqp_util:binding_def(),
	Declare :: i4e_amqp_util:queue_declare()
			 | i4e_amqp_util:exchange_declare()
			 | i4e_amqp_util:binding_declare().
%% ====================================================================
declare(Ch, queue, Q) ->
	QD = i4e_amqp_util:queue(Q),
	#'queue.declare_ok'{} = amqp_channel:call(Ch, QD),
	QD;
declare(Ch, exchange, E) ->
	ED = i4e_amqp_util:exchange(E),
	#'exchange.declare_ok'{} = amqp_channel:call(Ch, ED),
	ED;
declare(Ch, binding, B) ->
	BD = i4e_amqp_util:binding(B),
	#'queue.bind_ok'{} = amqp_channel:call(Ch, BD),
	BD.

