#!/bin/sh
# rsync-script for the DragonFly snapshots-dir
HOST=chlamydia.fs.ei.tum.de

if [ `whoami` != 'mirror' ];then
	echo 'Must be run my the user "mirror"'
	exit 1
fi

cd /var/www/ftp/pub/DragonFly

if [ $? != 0 ]; then
	echo 'Fix the path!'
	exit 1
fi

# Not the output syntax, important for status pages

if rsync -azv --delete --force ${HOST}::dflysnap/  ./
then
	echo "OK,/pub/DragonFly,$HOST,`date`"
	(cd iso-images/; md5 * > md5.txt)
	exit 0
else
	echo "NOTOK,/pub/DragonFly,$HOST,`date`"
	exit 1
fi
