#!/bin/sh
# rsync-script for the DragonFly snapshots-dir
HOST=chlamydia.fs.ei.tum.de

if [ `whoami` != 'mirror' ];then
	echo 'Must be run by the user "mirror"'
	exit 1
fi

cd /var/www/ftp/pub/DragonFly

if [ $? != 0 ]; then
	echo 'Fix the path!'
	exit 1
fi

# Not the output syntax, important for status pages

mirror_sync() {
	rsync -azv --exclude '.*' --delete --force ${HOST}::dflysnap/  ./ 2>/dev/null
}

TRY=0
mirror_wrapper() {
	TRY=$(($TRY + 1))
	mirror_sync
	if [ $? -eq 0 ]; then
		echo "OK,/pub/DragonFly,$HOST,`date`"
		find . -type d \! -exec chmod 755 {} \;
		(cd iso-images/; md5 * > md5.txt)
		exit 0
	else
		if [ $TRY -lt 3 ]; then
			mirror_wrapper
		else
			echo "NOTOK,/pub/DragonFly,$HOST,`date`"
			exit 1
		fi
	fi
}
mirror_wrapper
