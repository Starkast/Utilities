#!/bin/sh

uvm_data=`vmstat -m | grep "    UVM amap" | sed 's/K/ /g'`

max_uvm=`echo $uvm_data | awk '{ print $5 }'`
cur_uvm=`echo $uvm_data | awk '{ print $3 }'`

if [ "$cur_uvm" -ge `echo "${max_uvm}/1.3"|bc` ]; then
	restart_text=`/bin/sh /opt/sbin/apache_restart.sh 2>&1`
	echo "UVM amap value: ${cur_uvm} at `date` caused a restart\n\nApache output:\n${restart_text}" | mail -s "Phoo: Apache restarted by UVM monitor" root
fi
