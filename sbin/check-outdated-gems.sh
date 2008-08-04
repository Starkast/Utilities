#!/bin/sh
PATH=/usr/local/bin:/usr/local/sbin:.:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin:/opt/bin:/opt/sbin

tmpfile=`mktemp`

`gem outdated > $tmpfile`

if [ -s $tmpfile ]; then
	cat $tmpfile | mail -s '[Phoo] Ruby Gems updates' root
fi
