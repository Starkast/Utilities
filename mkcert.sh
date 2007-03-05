#!/bin/sh

if [ X"$1" != X"" ]; then
	SERVICE=$1
else
	echo "Usage: mkcert.sh <service>"
	exit 1
fi

OPENSSL="/usr/sbin/openssl"
SSLDIR="/etc/ssl"
OPENSSLCONFIG=$SSLDIR/$SERVICE.cnf
KEYDIR=$SSLDIR/private
CERTREQ=$KEYDIR/$SERVICE.crs
CERTFILE=$SSLDIR/$SERVICE.crt
KEYFILE=$KEYDIR/$SERVICE.key

if [ ! -f $OPENSSLCONFIG ]; then
	echo "Could not find $OPENSSLCONFIG"
	exit 1
fi

if [ ! -d $KEYDIR ]; then
	echo "$SSLDIR/private directory doesn't exist"
	exit 1
fi

if [ -f $CERTREQ ]; then
	echo "$CERTREQ already exists, won't overwrite"
	exit 1
fi

if [ -f $KEYFILE ]; then
	echo "$KEYFILE already exists, won't overwrite"
	exit 1
fi

$OPENSSL req -new -nodes -config $OPENSSLCONFIG -out $CERTREQ -keyout $KEYFILE || exit 2
echo "\nPaste this CSR at the signing service:\n"
cat $CERTREQ
echo "\nThen save the signed key to $CERTFILE\n"
