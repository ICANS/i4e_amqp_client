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
%% @doc Simple processor, which calls callback functions on delivery.
%%
%% Primarily used by i4e_amqp_consumer.
%%
%% Implements behaviour amqp_gen_consumer.
%%
%% init/1 expects a proplist containing:
%%
%% ```{acknowledge, all | ok | error}''' - optional (default: all)  
%% Messages will be acknowledged according to this setting.
%% all -> acknowledge all messages
%% ok -> acknowledge only if callback succeeded
%% error -> acknowledge only if callback returned an error
%%
%% ```{deliver_cb, CbFun}''' - mandatory
%% CbFun must be a fun/1 and will be called upon delivery with #amqp_msg{} as only argument.
%% It must return one of
%% * ok - success, acknowledge according to acknowledge mode
%% * {ok, ack} - success, acknowledge even if acknowledge mode is set to error
%% * {ok, leave} - success, don't acknowledge even if acknowledge mode is set to ok or all
%% * {error, Reason} - failure, don't acknowledge unless acknowledge mode is set to all or error
%%
%% ```{error_cb, CbFun}''' - optional
%% CbFun must be a fun/1 and will be called when deliver_cb returned {error, term()}.
%% The argument is a tuple of {Reason, Deliver, Msg, Channel} with
%% * Reason :: term() - whatever your deliver_cb returned as reason
%% * Deliver :: #'basic.deliver'{} - so your error_cb can still acknowledge the message. Keep in mind, that depending on your settings the message might already have been acknowledged.
%% * Msg :: #amqp_msg{} - the initial message
%% * Channel :: pid() - the AMQP channel pid 

-module(i4e_amqp_callback_processor).
-behaviour(amqp_gen_consumer).
-export([init/1,
		 handle_consume/3,
		 handle_consume_ok/3,
		 handle_cancel/2,
		 handle_cancel_ok/3,
		 handle_deliver/3,
		 handle_info/2,
		 handle_call/3,
		 terminate/2]).

-export([is_valid_opts/1]).

-include_lib("amqp_client/include/amqp_gen_consumer_spec.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([start_opt/0]).
-type start_opt() :: {deliver_cb, cb_def()}
				   | {error_cb, cb_def()}
				   | {acknowledge, acknowledge_mode()}.
-type cb_def() :: {module(), function()}
				| {module(), function(), [any()]}
				| fun().
-type acknowledge_mode() :: all
						  | ok
						  | error.


%% ====================================================================
%% API functions
%% ====================================================================
is_valid_opts(Opts) ->
	proplists:is_defined(deliver_cb, Opts).

%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, {deliver_cb, channel, error_cb, acknowledge}).

-define(GV(K,L), proplists:get_value(K,L)).
-define(GV(K,L,D), proplists:get_value(K,L,D)).

%% init/1
%% ====================================================================
%% @doc amqp_gen_consumer:init/1
%%
%% This callback is invoked by the channel, when it starts
%% up. Use it to initialize the state of the consumer. In case of
%% an error, return {stop, Reason} or ignore.
%% ====================================================================
init([Opts]) ->
	ErrorCb = case ?GV(error_cb, Opts) of
				  undefined -> fun(_X) -> ok end;
				  ErrorDef -> get_cb(ErrorDef)
			  end,
	{ok, #state{
				deliver_cb = get_cb(?GV(deliver_cb, Opts)),
				error_cb = ErrorCb,
				acknowledge = ?GV(acknowledge, Opts, all)
			   }}.


%% handle_consume/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_consume/3
%%
%% This callback is invoked by the channel before a basic.consume
%% is sent to the server.
%% ====================================================================
handle_consume(#'basic.consume'{}=_Consume, _Sender, State) ->
	{ok, State}.


%% handle_consume_ok/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_consume_ok/3
%%
%% This callback is invoked by the channel every time a
%% basic.consume_ok is received from the server. Consume is the original
%% method sent out to the server - it can be used to associate the
%% call with the response.
%% ====================================================================
handle_consume_ok(#'basic.consume_ok'{}=_ConsumeOk, #'basic.consume'{}=_Consume, State) ->
	{ok, State}.


%% handle_cancel/2
%% ====================================================================
%% @doc amqp_gen_consumer:handle_cancel/2
%%
%% This callback is invoked by the channel every time a basic.cancel
%% is received from the server.
%% ====================================================================
handle_cancel(#'basic.cancel'{}=_Cancel, State) ->
	{ok, State}.


%% handle_cancel_ok/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_cancel_ok/3
%%
%% This callback is invoked by the channel every time a basic.cancel_ok
%% is received from the server.
%% ====================================================================
handle_cancel_ok(#'basic.cancel_ok'{}=_CancelOk, #'basic.cancel'{}=_Cancel, State) ->
	{ok, State}.


%% handle_deliver/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_deliver/3
%%
%% This callback is invoked by the channel every time a basic.deliver
%% is received from the server.
%% ====================================================================
handle_deliver(#'basic.deliver'{delivery_tag=Tag}=Deliver,
			   #amqp_msg{}=Msg,
			   #state{deliver_cb=Cb, channel=Ch, acknowledge=AckMode}=State) ->
	Ack = case Cb(Msg) of
			  {error, Reason} ->
				  ErrorCb = State#state.error_cb,
				  ErrorCb({Reason, Deliver, Msg, Ch}),
				  shall_ack(AckMode, error);
			  X ->
				  shall_ack(AckMode, X)
		  end,
	case Ack of
		true ->
			amqp_channel:cast(Ch, #'basic.ack'{delivery_tag=Tag}),
			ok;
		false ->
			ok
	end,
	{ok, State}.


%% handle_info/2
%% ====================================================================
%% @doc amqp_gen_consumer:handle_info/2
%%
%% This callback is invoked the consumer process receives a
%% message.
%% ====================================================================
handle_info(_Info, State) ->
    {ok, State}.


%% ====================================================================
%% handle_call/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_call/3
%%
%% This callback is invoked by the channel when calling
%% amqp_channel:call_consumer/2. Reply is the term that
%% amqp_channel:call_consumer/2 will return. If the callback
%% returns {noreply, _}, then the caller to
%% amqp_channel:call_consumer/2 and the channel remain blocked
%% until gen_server2:reply/2 is used with the provided From as
%% the first argument.
%% ====================================================================
handle_call({set_channel, Channel}, _From, S) ->
	{reply, ok, S#state{channel = Channel}};
handle_call(_Msg, _From, State) ->
	{reply, ok, State}.


%% terminate/2
%% ====================================================================
%% @doc amqp_gen_consumer:terminate/2
%%
%% This callback is invoked by the channel after it has shut down and
%% just before its process exits.
%% ====================================================================
terminate(_Reason, _State) ->
    ok.




%% ====================================================================
%% Internal functions
%% ====================================================================

%% get_cb/1
%% ====================================================================
%% @doc Get callback fun from given Definition
-spec get_cb(Definition) -> fun() when
	Definition :: {Module, Function}
				| {Module, Function, Args}
				| fun(),
	Module :: module(),
	Function :: atom(),
	Args :: list().
%% ====================================================================
get_cb(Definition) ->
	case Definition of
		{M, F} -> fun(X) -> erlang:apply(M, F, [X]) end;
		{M, F, A} -> fun(X) -> erlang:apply(M, F, [X | A]) end;
		F when is_function(F, 1) -> F
	end.


%% shall_ack/2
%% ====================================================================
%% @doc Decide if delivery should by acknowledged
-spec shall_ack(AckMode, Result) -> boolean() when
	AckMode :: all | ok | error,
	Result :: ok | {ok, ack} | {ok, leave} | error.
%% ====================================================================
shall_ack(all, _) ->			true;
shall_ack(ok, ok) ->			true;
shall_ack(_, {ok, ack}) ->		true;
shall_ack(_, {ok, leave}) ->	false;
shall_ack(ok, error) ->			false;
shall_ack(error, ok) ->			false;
shall_ack(error, error) ->		true.
