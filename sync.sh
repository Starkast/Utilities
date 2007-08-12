usage() {
	echo 'Usage: sync ssh.starkast.net:/var/www'
}


if [ X"${1}" == X"" ]; then
	usage; exit 1
fi

HOST=`echo "$1"|sed 's/:.*//'`
DIR=`echo "$1"|sed 's/.*://'`

if [ X"${HOST}" == X"" -o X"${DIR}" == X"" -o X"${HOST}" == X"${DIR}" ]; then
	usage; exit 1
fi

/usr/bin/sudo /usr/local/bin/rsync \
	-az --delete -e 'ssh -i /home/sync/.ssh/sync -T' \
	sync@${HOST}:${DIR} ${DIR}
