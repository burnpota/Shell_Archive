#!/bin/bash

if [ $1 == "--init" ]
then
	SH_PATH="$( cd "$( dirname "$0" )" && pwd -P )"
	SH_FILE=`echo ${0} | awk -F "/" '{print $NF}'`
	echo "Wellcome to TG_PS_MON_TOOL!!"
	read -p "Enter First PID : " PIDNUM1 
	read -p "Enter Second PID : " PIDNUM2
	read -p "Enter Third PID : " PIDNUM3
	read -p "Enter Fourth PID : " PIDNUM4
	read -p "Enter Fifth PID : " PIDNUM5
	if [ -z $PIDNUM1 ] || [ -z $PIDNUM2 ] || [ -z $PIDNUM3 ] || [ -z  $PIDNUM4 ] || [ -z $PIDNUM5 ]
	then
		echo "FAILED!! : INPUT all PID numbers (NO EMPTY)"
		exit 1
	fi
	echo "* */1 * * * root ${SH_PATH}/${SH_FILE} ${PIDNUM1} ${PIDNUM2} ${PIDNUM3} ${PIDNUM4} ${PIDNUM5}" >> /etc/crontab
	echo "Success!! Check the /etc/crontab"

elif [ $1 == "--help" ]
then
	echo " ### TimeGate Process resource using Monitoring Tool ###
Use --init option for starting set up the monitoring tool then input 5 PIDs 
DO NOT MAKE EMPTY"
else
	PID1=$1
	PID2=$2
	PID3=$3
	PID4=$4
	PID5=$5
	if [ -z $PID1 ] || [ -z $PID2 ] || [ -z $PID3 ] || [ -z  $PID4 ] || [ -z $PID5 ]
	then
		logger -p error "TG_PS_MON_TOOL:[ERROR] MISSING PIDs. Check the /etc/crontab"
		exit 1
	fi
	
	CU_DATE=`date "+%Y-%m-%d"`
	CU_TIME=`date "+%H:%M:%S"`
	
	if [ ! -f /var/log/ps_usage_all.csv ]
	then
		touch /var/log/ps_usage_all.csv
		echo "USR,PID,CPU,MEM,START,COMMAND,TIME" > /var/log/ps_usage_all.csv
	fi
	
	for i in $PID1 $PID2 $PID3 $PID4 $PID5
	do
		
		if [ ! -f /var/log/ps_usage_${i}.csv ]
		then
			touch /var/log/ps_usage_${i}.csv
			echo "USR,PID,CPU,MEM,START,COMMAND,TIME" > /var/log/ps_usage_${i}.csv
		fi
		ps aux | awk -v PID=$i -v TIME=$CU_TIME -v DATE=$CU_DATE '{if($2==PID){print $1","$2","$3"%,"$4"%,"$9","$11","DATE" "TIME}}' >> /var/log/ps_usage_${i}.csv
		ps aux | awk -v PID=$i -v TIME=$CU_TIME -v DATE=$CU_DATE '{if($2==PID){print $1","$2","$3"%,"$4"%,"$9","$11","DATE" "TIME}}' >> /var/log/ps_usage_all.csv
	done
fi
