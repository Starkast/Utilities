#!/bin/sh

# To be installed in /usr/local/libexec/check_mysql_replication.sh
# 
# and in crontab like:
# 
# # Check MySQL
# # Mail root if something is wrong
# @daily /bin/sh /usr/local/libexec/check_mysql_replication.sh|mail -s "MySQL replication failed on Phoo" -E root


mysql_status=`echo "SHOW SLAVE STATUS \G"|/usr/local/bin/mysql --defaults-file=/root/.my.cnf`

# Get some status codes
status_rows=`echo "${mysql_status}"|/usr/bin/awk '/Slave_(IO|SQL)_Running/ {print $2}'`

# Check if something isn't running
for row in $status_rows; do
	# If No, something is broken
	if [ "$row" = "No" ]; then
		echo "MySQL replication failed!\n"
		echo "$mysql_status"
	fi
done
