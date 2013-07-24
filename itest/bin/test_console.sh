#!/bin/bash
BASEDIR=$(readlink -f "$(dirname $0)/../../")
NODE="-sname i4e_amqp_client_test"

cd $BASEDIR/itest/helpers
erlc -I $BASEDIR/deps *.erl

cd $BASEDIR

erl $NODE -config $BASEDIR/itest/config/interactive.config -pa $BASEDIR/deps/*/ebin $BASEDIR/ebin $BASEDIR/src/*/*/deps/*/ebin $BASEDIR/src/*/*/ebin $BASEDIR/itest/helpers -s i4e_amqp_client start
