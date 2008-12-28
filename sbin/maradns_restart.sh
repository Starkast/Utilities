#!/bin/sh
pkill -U _maradns -x maradns
if [ $? = 0 ]
then
    echo "maradns killed."
else
    echo "maradns wasn't running."
fi

/usr/local/sbin/maradns >/dev/null &

pgrep -x maradns >/dev/null
if [ $? = 0 ]
then
    echo "maradns started."
else
    echo "maradns did *NOT* start."
fi
