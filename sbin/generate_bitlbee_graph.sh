# $Id: generate_bitlbee_graph.sh,v 1.6 2008/03/01 17:22:52 jage Exp $
#
# Written by Johan Eckerström <johan@jage.se>


DEST_HOME=/var/www/services/im/statistics
BACK_RRD=/var/www/symon/misc/beaver_proc_bitlbee.rrd
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
		DEF:back_number=${BACK_RRD}:number:AVERAGE:step=1 \
		DEF:max_number=${RRD_HOME}/proc_${name}.rrd:number:MAX \
		DEF:back_max_number=${BACK_RRD}:number:MAX \
		DEF:min_number=${RRD_HOME}/proc_${name}.rrd:number:MIN \
		DEF:back_min_number=${BACK_RRD}:number:MIN \
		CDEF:null=number,number,- \
		CDEF:nodata=number,UN,0,* \
		LINE1:nodata#FF0000 \
		COMMENT:"\t  Phoo \t  Beaver" \
		COMMENT:"\n" \
		COMMENT:"\t" \
		AREA:max_number#ffd9e3:"Max" \
		GPRINT:max_number:MAX:"%2.0lf"  \
		AREA:back_max_number#fff886:"Max" \
		GPRINT:back_max_number:MAX:"%2.0lf \n"  \
		COMMENT:"\t" \
		AREA:number#aced5f:"Avg" \
		GPRINT:number:AVERAGE:"%2.0lf" \
		AREA:back_number#f37b46:"Avg" \
		GPRINT:back_number:AVERAGE:"%2.0lf \n" \
		COMMENT:"\t" \
		AREA:min_number#91de36:"Min" \
		GPRINT:min_number:MIN:"%2.0lf" \
		AREA:back_min_number#f65b2b:"Min" \
		GPRINT:back_min_number:MIN:"%2.0lf \n" \
		LINE1:number#484947 \
		LINE1:back_number#484947 \
		COMMENT:"\t" \
		COMMENT:"---" \
		COMMENT:"\n" \
		GPRINT:max_number:LAST:"\t  Latest %2.0lf \n" > /dev/null
}

# Normal size
plot_proc bitlbee bitlbee_last_600_days -51840000 800 200
plot_proc bitlbee bitlbee_last_year -29030400 800 200
plot_proc bitlbee bitlbee_last_six_months -14515200 800 200
plot_proc bitlbee bitlbee_last_month -2419200 800 200
plot_proc bitlbee bitlbee_last_week -604800 800 200
plot_proc bitlbee bitlbee_last_day -86400 800 200

# Small
plot_proc bitlbee small_bitlbee_last_day -86400 400 100
plot_proc bitlbee small_bitlbee_last_month -2419200 400 100
