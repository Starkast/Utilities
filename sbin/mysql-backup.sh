#!/bin/sh
#
# Johan Eckerström <johan@starkast.net>
#

# Configuration
#

USERNAME='root'
PASSWORD=''
HOSTNAME='localhost'
CHARSET='latin1'
DIRECTORY='/archive/backup/mysql'
OWNER='root'
GROUP='backup'
DIR_CHMOD='0750'
FILE_CHMOD='0640'

# Don't touch the stuff below

PATH='/bin:/sbin:/usr/bin:/usr/local/bin'
SELF=`basename "$0"`
set -o posix

usage () {
	cat << __EOT
Usage: ${SELF} option
Options: -d, Directory to save dumps in
         -p, Plain-text, no gzip
__EOT

	exit 1
}

check_self () {
}

check_tools () {
	if [ ! -x mysqldump -a -x mysql ]; then
		echo "Can not find MySQL-binaries" && exit 1
	fi

	if [ ! ${GZIP} -a -x gzip ]; then
		echo "Can not find gzip-binary" && exit 1
	fi
}

create_directory () {
	if [ ! -w ${DIRECTORY} ]; then
		echo "Can not write in ${DIRECTORY}" && exit 1
	fi

	SAVEDIR=${DIRECTORY}/`date +%Y`/`date +%m`/`date +%d`
	
	if [ ! -d ${SAVEDIR} ]; then
		mkdir -p ${SAVEDIR} && chmod ${DIR_CHMOD} ${SAVEDIR} && chown ${OWNER}:${GROUP} ${SAVEDIR}
	fi

	if [ ! -w ${SAVEDIR} ]; then
		echo "Can not write in ${SAVEDIR}" && exit 1
	fi
}

find_databases () {
	DATABASES=`mysql -u${USERNAME} -p${PASSWORD} -h${HOSTNAME} -e 'SHOW DATABASES \G' | grep 'Database:' | cut -f 2 -d " "`

	if [ ! $? -eq 0 ]; then
		echo "Could not find any databases" && exit 1
	fi
}

dump_databases () {
	for i in ${DATABASES}; do
		file=${SAVEDIR}/${i}-`date +%Y-%m-%d_%H%M`

		if [ ${GZIP} = 1 ]; then
			file="${file}.gz"
			mysqldump --default-character-set ${CHARSET} -u${USERNAME} -p${PASSWORD} -h${HOSTNAME} ${i} | gzip > ${file}
		else
			mysqldump --default-character-set ${CHARSET} -u${USERNAME} -p${PASSWORD} -h${HOSTNAME} ${i} > ${file}
		fi

		chmod ${FILE_CHMOD} ${file} && chown ${OWNER}:${GROUP} ${file}
	done
}

check_permissions () {
	# Check directories
	find ${DIRECTORY} -type d \! \( -perm ${DIR_CHMOD} -and -user ${OWNER} -and -group ${GROUP} \) \
		-exec chown ${OWNER}:${GROUP} '{}' ';' \
		-exec chmod ${DIR_CHMOD} '{}' ';'

	# Check files
	find ${DIRECTORY} -type f \! \( -perm ${FILE_CHMOD} -and -user ${OWNER} -and -group ${GROUP} \) \
		-exec chown ${OWNER}:${GROUP} '{}' ';' \
		-exec chmod ${DIR_CHMOD} '{}' ';'
}

GZIP=1

while getopts "d:p" c; do
	case $c in
		d)  DIRECTORY=${OPTARG} ;;
		p)  unset GZIP ;;
		*)  usage ;;
	esac
done

check_tools
find_databases
create_directory
dump_databases
check_permissions
