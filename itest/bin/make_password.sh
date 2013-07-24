#!/bin/sh
NUM_CHARS=80
FILENAME='.password'
CHARSET='a-zA-Z0-9-_@#%^:='
while getopts f:c:n: OPTION
do
	case $OPTION in
		f)
			FILENAME="$OPTARG"
			;;
		n)
			NUM_CHARS="$OPTARG"
			;;
		c)
			CHARSET="$OPTARG"
			;;
	esac
done

cat /dev/urandom | tr -dc $CHARSET | head -c $NUM_CHARS > $FILENAME
