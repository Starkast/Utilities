if [ X"${1}" = X"" -o X"${2}" = X"" ]; then
	echo "usage: machine type"
	exit 1
fi

if [ ! `whoami` = backup ]; then
	echo "sorry, this is for backup"
	exit 1
fi

# Notice that && and ; are VERY important here
sudo chmod 0700 /backup/$1 && \
sudo mount -uo rw /backup/$1/snapshots && \
nice -n 20 sudo rsnapshot -c /etc/rsnapshot/$1.conf $2 ; \
sudo mount -uo ro /backup/$1/snapshots && \
sudo chmod 0755 /backup/$1
