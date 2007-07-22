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

mirror_sync() {
	rsync -azv --delete --force ${HOST}::dflysnap/  ./
}

TRY=0
mirror_wrapper() {
	TRY=$(($TRY + 1))
	mirror_sync
	if [ $? -eq 0 ]; then
		echo "OK,/pub/DragonFly,$HOST,`date`"
		(cd iso-images/; md5 * > md5.txt)
		exit 0
	else
		# $? -gt 6 means that if the error code isn't really bad,
		# it'll try again
		if [ $TRY -lt 6 -a $? -gt 6 ]; then
			mirror_wrapper
		else
			echo "NOTOK,/pub/DragonFly,$HOST,`date`"
			exit 1
		fi
	fi
}
mirror_wrapper
