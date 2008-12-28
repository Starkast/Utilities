#!/bin/sh

if test `whoami` != root; then
	echo 'You must be root'
	exit 1
fi

BINARY=$1
CHROOT=$2

# Make sure we get the parameters
if [ X"${1}" = X"" -o X"${2}" = X"" ]; then
	echo "usage: $0 binary chroot"
	exit 1
fi

# Look for the file
if [ ! -f $BINARY ]; then
	echo "Could not find $BINARY"
	exit 1
fi

# Check for SUID/SGID binaries, dangerous
if [ -u $BINARY -o -g $BINARY ]; then
	echo 'No SUID or SGID binaries!'
	exit 1
fi

# Make sure we try to install to a directory
if [ ! -d $CHROOT ]; then
	echo "$CHROOT is not a directory"
	exit 1
fi

# Get the libs
LIBS=`ldd $BINARY | awk '/rlib/ { print $7 }'`

# If this is PHP, we have to check the modules too
if [ `echo $BINARY | grep 'php-fastcgi'` ]; then
	echo "Checking $BINARY and PHP-modules"
	LIBS="$LIBS `for i in /var/www/lib/php/modules/*; do
	        ldd $i
	done | grep 'rlib' | awk '{ print $7 }' | sort | uniq`"
fi

bindir=`dirname $BINARY`
if [ ! -d ${CHROOT}/${bindir} ]; then
	mkdir -p ${CHROOT}/${bindir}
fi

echo 'installing binary'
install -m 755 -o root -g wheel ${BINARY} ${CHROOT}/${BINARY}

if test "x$LIBS" = "x"; then
	exit 0
fi

echo 'copying libs'
for lib in $LIBS; do
	dir=`dirname $lib`
	chrootdir=${CHROOT}/$dir
	if [ ! -d $chrootdir ]; then
		mkdir -p $chrootdir
	fi
	cp -p $lib $chrootdir
	echo " `basename $lib`"
done

if [ ! -f ${CHROOT}/usr/libexec/ld.so ]; then
	echo 'copying ld.so to chroot'
	if [ ! -d ${CHROOT}/usr/libexec ]; then
		mkdir -p ${CHROOT}/usr/libexec
	fi
	cp -p /usr/libexec/ld.so ${CHROOT}/usr/libexec/ld.so
fi

if [ ! -f ${CHROOT}/sbin/ldconfig ]; then
	echo 'copying ldconfig to chroot'
	if [ ! -d ${CHROOT}/sbin ]; then
		mkdir -p ${CHROOT}/sbin
	fi
	cp -p /sbin/ldconfig ${CHROOT}/sbin/ldconfig
fi

echo 'running ldconfig in chroot'
if [ ! -d ${CHROOT}/var/run ]; then
	mkdir -p ${CHROOT}/var/run
fi
chroot ${CHROOT} /sbin/ldconfig /usr/lib /usr/local/lib /usr/X11R6/lib
