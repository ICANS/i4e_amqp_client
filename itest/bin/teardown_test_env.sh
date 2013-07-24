#!/bin/sh

err() { echo "$@" >&2; exit 1; }

BASEDIR=$(readlink -f "$(dirname $0)/..")
CONFIGDIR="$BASEDIR/config"

PASSWORD_FILE="$CONFIGDIR/password.do_not_commit"
CT_CONFIG_FILE="$CONFIGDIR/ct.config"
INTERACTIVE_CONFIG_FILE="$CONFIGDIR/interactive.config"
TYPE_FILE="$CONFIGDIR/type.do_not_commit"

if [ ! -e "$TYPE_FILE" ]; then
	err "Type file missing. Expected file: $TYPE_FILE"
fi

AMQP_TYPE=$(cat "$TYPE_FILE")

case $AMQP_TYPE in
	"manual")
		echo "Skipping configuration of AMQP broker"
		;;
	"rabbitmq")
		echo "Configuring rabbitmq broker"
		rabbitmqctl clear_permissions -p i4e_amqp_client_itest i4e_amqp_client_itest
		rabbitmqctl delete_vhost i4e_amqp_client_itest
		rabbitmqctl delete_user i4e_amqp_client_itest
		;;
	*)
		err "Invalid AMQP type ($AMQP_TYPE)"
		;;
esac

echo "Removing configuration files"

# using if instead of -f to avoid desasters like CONFIG_FILE=" -r /"
rm_file() { if [ -e "$1" ]; then rm $1; fi; }

rm_file "$TYPE_FILE"
rm_file "$CT_CONFIG_FILE"
rm_file "$INTERACTIVE_CONFIG_FILE"
rm_file "$PASSWORD_FILE"

echo "\nOK\n"
