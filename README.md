i4e_amqp_client
================

i4e_amqp_client - the ICANS for Erlang AMQP Client - provides some helpers on top of amqp_client by rabbitMQ.

The main goals of this application are:
* Taking away some work for common, simple use cases
* Providing an easy way to configure producers, consumers, exchanges, queues and bindings with a configuration file

i4e_amqp_client is not supposed to be
* a replacement for amqp_client
* an abstraction from AMQP

Feedback, ideas, issues, contributions are very welcome.

See LICENSE

Terms
------

Apart from the usual terms used in AMQP context (see [rabbitmq tutorials](http://www.rabbitmq.com/getstarted.html)) there is one additional concept I'd like to mention.

### Setup
Setups can be used to declare exchanges, queue and bindings according to a configuration list (e.g. from the application config).
Depending on the configuration of 'teardown_on_stop' the setup will tear down all/some/none of the declarations it has made automatically.
Examples:
*{teardown_on_stop, [all]}* - Will tear down all declarations it has made
*{teardown_on_stop, [all_bindings]}* - Will tear down all bindings, but not exchanges or queues
*{teardown_on_stop, [{queue, [{queue, <<"abc">>}]}]}* - Will only tear down the queue <<"abc">>

Usage
------

### Static configuration

i4e_amqp_client uses [OTP application configuration](http://www.erlang.org/doc/design_principles/applications.html#id74282).
Use the [erl](http://www.erlang.org/doc/man/erl.html) option "-config <config file>" or [application:set_env/3](http://www.erlang.org/doc/apps/kernel/application.html#set_env-3) before starting the application (application:config_change/3 hasn't been implemented yet).
See itest/config/ct.config.template an example.

### Start

You can start i4e_amqp_client by calling *i4e_amqp_client:start/0* as OTP application.
You can also embed *i4e_amqp_consumer_sup*, *i4e_amqp_producer_sup* and/or *i4e_amqp_setup_sup* into your own supervision tree. See *i4e_amqp_consumer_sup:start_link/0,1*, *i4e_amqp_producer_sup:start_link/0,1* and *i4e_amqp_setup_sup:start_link/0,1*.
And last but not least you can start and use *i4e_amqp_producer*, *i4e_amqp_consumer* and *i4e_amqp_setup* directly.

### Starting / stopping consumers / producers

If you want to auto-start consumers/producers/setups on application startup, just put their definitions into the config. See itest/config/ct.config.template.
To dynamically start consumers/producers/setups use *i4e_amqp_client:start_consumer/1*/*i4e_amqp_client:start_producer/1*/*i4e_amqp_client:start_setup/1*.
You can stop a consumer with *i4e_amqp_client:stop_consumer/1*/*i4e_amqp_client:stop_producer/1*/*i4e_amqp_client:stop_setup/1*.

### The i4e_amqp_callback_processor

There is currently one message processor (i4e_amqp_callback_processor), which is implemented as amqp_gen_counsumer.
In order to use this, you have to set two callback functions:

The delivery callback - mandatory opt {deliver_cb, fun()} - is used to process incoming messages.
It can be specified in three versions:
- {Module, Function}, where Function has to accept exactly one parameter (the #amqp_msg{}).
- {Module, Function, Args}, where Function has to accept exactly size(Args)+1 parameters. The #amqp_msg{} will be prepended to the Args.
- fun/1, where the fun accepts exactly one parameter (the #amqp_msg{}).
The delivery_cb has to return:
- ok -> The message will be acknowledged if the acknowledge setting is set to all or ok 
- {ok, ack} -> The message will be acknowledged
- {ok, leave} -> The message will not be acknowledged
- {error, Reason} -> If you have specified an error_cb (see below) it will be called and the message will be acknowledged if the acknowledge setting is set to all or error

The error callback - optional opt {error_cb, fun/1} - is called whenever delivery_cb returns {error, Reason}.
error_cb has to accept exactly one parameter, which will be a 4-tuple of {Reason, #'basic.deliver'{}, #amqp_msg{}, ChannelPid}   
deliver_cb will be called whenever a message arrives. The first parameter will always be the #amqp_msg{}. You can specify  
- error_cb will be called if your deliver_cb returns {error, Reason}. 

### Tests

You need a running rabbitmq-server on 127.0.0.1:5672 for the integration tests

Before first test run, execute the following setup script. A rabbitmq user and vhost will be created. The user will get permissions to the newly created vhost. The password will be random, so you don't accidently expose your rabbitmq server. 
> sudo itest/bin/setup_test_env.sh

To run the actual tests use:
> make tests

If you want to tear down the test environment execute:
> sudo itest/bin/teardown_test_env.sh

If you want to create the configurations yourself copy ct.config.template to ct.config and interactive.config.template to interactive.config and set {{PASSWORD}} plus all changes you'd like to make. 
You can also run "itest/bin/setup_test_env.sh -t manual" (not as su) to just create the configurations. You must afterwards configure your broker accordingly.

Dependencies
-------------
Resolved by rebar.

* [amqp_client](http://github.com/jbrisbin/amqp_client) 

ToDos
------
- smarter waiting / parallelization of tests
- i4e_amqp_setup connect only when needed, disconnect after operation
- dynamic declaration / deletion in setups
- deletion in setup ("delete queue X and declare queue X again")
- as always: more tests (units, tear down)
- full example.config