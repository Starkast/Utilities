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

if rsync -azv --delete --force ${HOST}::dflysnap/  ./
then
	echo "Latest sync of /pub/DragonFly: "`date`
	( cd /var/www/ftp/pub/DragonFly/iso-images/; md5 * > md5.txt )
else
	echo "Could not sync /pub/DragonFly: "`date`
fi

exit 0
