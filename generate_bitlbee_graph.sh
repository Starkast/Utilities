# $Id: generate_bitlbee_graph.sh,v 1.4 2007/07/08 11:01:49 jage Exp $
#
# Written by Johan Eckerström <johan@jage.se>


DEST_HOME=/var/www/vhosts/im.starkast.net/statistics
RRD_HOME=/var/www/symon/rrds/phoo

plot_proc() {
	name=$1
	filename=$2
	start_time=$3
	width=$4
	height=$5

	rrdtool graph ${DEST_HOME}/${filename}.png \
		-t "${name} processes" \
		-v "number of processes" \
		-w ${width} \
		-h ${height} \
		-s ${start_time} \
		-e -1 \
		-E \
		DEF:number=${RRD_HOME}/proc_${name}.rrd:number:AVERAGE:step=1 \
		DEF:max_number=${RRD_HOME}/proc_${name}.rrd:number:MAX \
		DEF:min_number=${RRD_HOME}/proc_${name}.rrd:number:MIN \
		CDEF:null=number,number,- \
		CDEF:nodata=number,UN,0,* \
		LINE1:nodata#FF0000 \
		COMMENT:"\t" \
		AREA:max_number#ffd9e3:"max number" \
		GPRINT:max_number:MAX:"%2.0lf \n"  \
		COMMENT:"\t" \
		AREA:number#aced5f:"avg number" \
		GPRINT:number:AVERAGE:"%2.0lf \n" \
		COMMENT:"\t" \
		AREA:min_number#a5db65:"min number" \
		GPRINT:min_number:MIN:"%2.0lf \n" \
		COMMENT:"\t" \
		LINE1:number#484947 \
		GPRINT:max_number:LAST:"Latest \t %4.0lf \n" > /dev/null
}

# Normal size
plot_proc bitlbee bitlbee_last_year -29030400 500 200
plot_proc bitlbee bitlbee_last_six_months -14515200 500 200
plot_proc bitlbee bitlbee_last_month -2419200 500 200
plot_proc bitlbee bitlbee_last_week -604800 500 200
plot_proc bitlbee bitlbee_last_day -86400 500 200

# Small
plot_proc bitlbee small_bitlbee_last_day -86400 400 100
