#!/bin/sh

# config

USERS=`ls -1 /var/www/users`

WWW_USER='www'
CHROOT=""
USERDIR="/var/www/users"
SPAWNFCGI="/usr/local/bin/spawn-fcgi"
FCGIDIR="/var/www/fastcgi"
PHP="/usr/local/bin/php-fastcgi"

E="PHP_FCGI_MAX_REQUESTS=1000 \
	FCGI_WEB_SERVER_ADDRS='127.0.0.1' \
	PATH=$PATH"

# end config

# Special spawns
/usr/bin/pgrep -U starkast -x php-fastcgi > /dev/null
if [ ! $? -eq 0 ]; then
	SOCKETDIR="/var/www/services/fastcgi/"
	SOCKET="/var/www/services/fastcgi/php.socket"
	FCGI_E="$E USER=starkast"
	PHP_U="$PHP -c /var/www/services/etc/php.ini"
	TMP_DIR="/var/www/services/tmp"
	PHP_FCGI_CHILDREN=4

	if [ ! -d ${SOCKETDIR} ]; then
		mkdir ${SOCKETDIR}
	fi

	if [ ! -d ${TMP_DIR} ]; then
		mkdir ${TMP_DIR}
	fi

	env -i $FCGI_E $SPAWNFCGI -u starkast -U starkast -s $SOCKET -f "$PHP_U" -C $PHP_FCGI_CHILDREN -P $SOCKETDIR/php.pid 
	chmod -R 770 $SOCKETDIR
	chown -R starkast:$WWW_USER $SOCKETDIR
	chmod 700 $TMP_DIR
	chown starkast:starkast $TMP_DIR
fi

# Spawn FCGI
for i in ${USERS}; do
	/usr/bin/pgrep -U ${i} -x php-fastcgi > /dev/null
	if [ $? -eq 0 ]; then
		continue
	fi
	SOCKETDIR=${CHROOT}/${FCGIDIR}/${i}
	SOCKET=${FCGIDIR}/${i}/php.socket
	FCGI_E="$E USER=$i"
	PHP_U="$PHP -c /var/www/users/${i}/etc/php.ini -d error_log=/var/www/users/${i}/logs/php_error.log"
	TMP_DIR="/var/www/users/${i}/tmp"
	PHP_FCGI_CHILDREN=1
	PHP_FCGI_CHILDREN=`head -n 1 /etc/nginx/users/${i}.conf | awk '{ print $3 }'` 2>/dev/null
	if [ ! $? -eq 0 ]; then
		PHP_FCGI_CHILDREN=2
	fi

	if [ $PHP_FCGI_CHILDREN -eq 0 ]; then
		continue
	fi

	if [ $PHP_FCGI_CHILDREN -lt 2 ]; then
		PHP_FCGI_CHILDREN=2
	fi

	if [ $PHP_FCGI_CHILDREN -gt 10 ]; then
		PHP_FCGI_CHILDREN=10
	fi

	if [ ! -d ${SOCKETDIR} ]; then
		mkdir ${SOCKETDIR}
	fi

	if [ ! -d ${TMP_DIR} ]; then
		mkdir ${TMP_DIR}
	fi

	env -i $FCGI_E $SPAWNFCGI -u $i -U $i -s $SOCKET -f "$PHP_U" -C $PHP_FCGI_CHILDREN -P $SOCKETDIR.pid 
	chmod -R 770 $SOCKETDIR
	chown -R $i:$WWW_USER $SOCKETDIR
	chmod 700 $TMP_DIR
	chown $i:$i $TMP_DIR
done
