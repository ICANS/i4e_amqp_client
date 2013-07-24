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
%% @doc Supervisor for consumers.


-module(i4e_amqp_consumer_sup).
-behaviour(supervisor).
-export([init/1]).

%% ====================================================================
%% Types
%% ====================================================================
-export_type([consumer_def/0]).
-type consumer_def() :: [i4e_amqp_consumer:start_opt()].

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/0, start_link/1,
		 start_consumer/1, stop_consumers/0, which_consumers/0]).
-define(SERVER, ?MODULE).

%% start_link/0
%% ====================================================================
%% @doc Start singleton supervisor
-spec start_link() -> supervisor:startlink_ret().
%% ====================================================================
start_link() ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, []).


%% start_link/1
%% ====================================================================
%% @doc Start singleton supervisor and all Consumers
-spec start_link([Consumer]) -> {ok, pid()} when
	Consumer :: [i4e_amqp_consumer:start_opt()].
%% ====================================================================
start_link(Consumers) ->
	{ok, Pid} = ?MODULE:start_link(),
	lists:foreach(fun(C) -> ?MODULE:start_consumer(C) end, Consumers),
	{ok, Pid}.
	

%% start_consumer/1
%% ====================================================================
%% @doc Start consumer (transient)
-spec start_consumer([i4e_amqp_consumer:start_opt()]) -> Result when
	Result :: {error, Reason}
			| {ok, pid},
	Reason :: term().
%% ====================================================================
start_consumer(Opts) ->
	case supervisor:start_child(?SERVER, [Opts]) of
		{error, Reason} ->
			error_logger:error_report({?MODULE, start_consumer, {Opts, Reason}}),
			{error, Reason};
		{ok, Child, _} ->
			{ok, Child};
		X ->
			X
	end.


%% stop_consumers/0
%% ====================================================================
%% @doc Stop all consumers
-spec stop_consumers() -> ok.
%% ====================================================================
stop_consumers() ->
	lists:foreach(fun(Pid) ->
						  i4e_amqp_consumer:stop(Pid)
				  end,
				  which_consumers()).

%% which_consumers/0
%% ====================================================================
%% @doc Get list of running consumers
-spec which_consumers() -> [pid()].
%% ====================================================================
which_consumers() ->
	[Pid || {_, Pid, _, _} <- supervisor:which_children(?SERVER)].


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
	Child = {i4e_amqp_consumer, {i4e_amqp_consumer, start_link, []},
			 transient, 5000, worker, [i4e_amqp_consumer]},
    {ok,{{simple_one_for_one,2,10}, [Child]}}.

%% ====================================================================
%% Internal functions
%% ====================================================================


