#!/bin/sh

PATH=/usr/local/bin:/usr/local/sbin:.:/bin:/sbin:/usr/bin:/usr/sbin

echo 'Creating vhosts configuration' 
sudo /usr/local/bin/ruby /opt/create_apache_vhosts_include.rb
if [ $? -ne 0 ]; then
	echo "Apache vhosts creation failed"
	exit 1
fi
sudo /usr/sbin/apachectl configtest
if [ $? -ne 0 ]; then
	echo "Apache syntax error in config!"
	exit 1
fi
sudo /usr/sbin/apachectl stop
for i in 1 2 3 4 5 6 7 8 9 10; do
	if [ -z `pgrep -U www -f 'httpd: parent'` ]; then
		sudo -c www /usr/sbin/apachectl startssl
		if [ $? -eq 0 ]; then
			sudo /opt/create_apache_sites_page.rb
		fi
		exit 0
	else
		sleep 1
	fi
done
echo "Apache won't shut down!"
exit 1
