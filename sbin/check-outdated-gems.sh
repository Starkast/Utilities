#!/bin/sh
PATH=/usr/local/bin:/usr/local/sbin:.:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin:/opt/bin:/opt/sbin

# This should work on both FreeBSD and OpenBSD
tmpfile=`mktemp -t gems.XXXXXXXXXXXX`

`gem outdated > $tmpfile`

if [ -s $tmpfile ]; then
	cat $tmpfile | mail -s "[`hostname -s`] Ruby Gems updates" root
fi
