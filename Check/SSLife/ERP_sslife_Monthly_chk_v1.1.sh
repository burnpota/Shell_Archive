#!/bin/bash

ma_dir=`pwd`
FILTERED="(debug1:|Libgcrypt|slice|Monitoring|SQLAnywhere|maxpatrl|EMF|sendmail|SAP...|CROND|ptymonitor|Temperature|Could not obtain|vmware-modconfig|vsftpd|PAM|Veritas|avrd|tldd|AgentFramwork|VCS ERROR V|ltid|automount|pbrun|Basis|This host is not entitled to run Veritas Storage Foundation|MTIOCGET failed on VTL_|ioctl error on VTL|sgaSol|polltracking|businessobjects|boe_|PERC H730 Mini|smhMonitor|Connection reset by peer|Failed publickey for sliida from|IPv6|rpcbind*warning\: cannot open|NTPCheck \: reach shift register something wrong|BPM_EMS_FAIL_|VxVM vxdmp|INFO|VCS CRITICAL V|restricted-command|PERC H710 Mini|MQSeries|NAS-monitor|root check failed|FailedPassword|PBFail|bpjava-msvc|notice\:|infoi|errorlog.|postfix|PHY_UPDOWN|LINK_UPDOWN|vpnserv|amanda|gpagent|Stopping User Slice|pblighttpd|Rejected send message|lsass|netlogon|st.*\[sg|netbackup|nbvault|oraclei|mssql|CacheRequest|pblogd|pbmasterd|hpasmlited|pam_unix.*authentication failure|postdrop|rabbitmq|awx_task|{|nodekeeper|security-gateway|nginx|server|elasticsearch|}\.sh|\/etc\/hosts.*Permission denied|segfault|kubelet|unbound-anchor|pci.*BAR|ata.*SATA link down|systemd: Stopp|Cleaning Up and Shutting Down Daemons|seoswd|sftp-server.*\/{|stop|shutdown|error}|safedb)"

LOGCHKFILE="${ma_dir}/extract/logs"
MPATHCHKFILE="${ma_dir}/extract/check_multipath.txt"
BONDCHKFILE="${ma_dir}/extract/check_bonding.txt"
NFSCHKFILE="${ma_dir}/extract/check_NFS.txt"
NTPCHKFILE="${ma_dir}/extract/check_ntp.txt"
DAEMONCHKFILE="${ma_dir}/extract/check_daemon.txt"
REPORTFILE="${ma_dir}/extract/report.csv"

if [ ! -d ${ma_dir}/extract ]
then
	mkdir ${ma_dir}/extract
	mkdir ${ma_dir}/extract/logs
	touch $LOGCHKFILE
	touch $MPATHCHKFILE
	touch $BONDCHKFILE
	touch $NFSCHKFILE
	touch $NTPCHKFILE
	touch $DAEMONCHKFILE
	touch $REPORTFILE
fi

for i in {1..20}
do
	arr_per[`expr $i - 1`]=`expr $i \* 5`
done

function per_bar(){
    bar=`for i in ${arr_per[@]} 
        do
            if [ $i -le $1 ]
            then
                echo -n '#'

            else
                echo -n '-'
            fi
        done`

    echo -ne "Progress [${bar}](${1}%)\r"
}


function file_unzip
{
	cd $ma_dir
	total_num=`ls *.gz | wc -l`
	cur_num=1
	
	echo "1. Unzip *.gz files"
	for i in `ls -al ./*.gz | awk '{print $9}'`
	do
		tar xf $i 
		echo -ne "Zip File : ${i}             \n"
        cur_per=`echo "" | awk -v cur_num=$cur_num -v total_num=$total_num '{printf "%d", cur_num/total_num*100}'`
        per_bar $cur_per
		echo -ne "\b\r"
        cur_num=`expr $cur_num + 1`
	done 
	echo -e "\033[31;1mDONE\033[0m                                                                     \n"
}

function hostname_check
{
	echo "2. hostname duplication check start~"
	arr_ulist=($(ls -l | grep ^d | grep -v extract |  awk '{print $9}' | awk -F "_" '{for(i=1;i<=NF;i++){if(i==1){printf $i}else{if($i==$NF){printf "\n"}else{printf "_"$i}}}}' | sort -u | tr '\n' ' '))
	total_num=${#arr_ulist[@]}
	cur_num=1
	for i in ${arr_ulist[@]}
	do
		echo -ne "Host Name : ${i}                       \n"
	    file_ct=`ls -l | grep ^d | awk '{print $9}' |grep ^$i | wc -l`
	    if [ $file_ct -gt 1 ] 
	    then
	        echo -ne "\b\rHost Name : ${i} is duplicated     \n\n"
	    fi
        cur_per=`echo "" | awk -v cur_num=$cur_num -v total_num=$total_num '{printf "%d", cur_num/total_num*100}'`
        per_bar $cur_per
		echo -ne "\b\r"
        cur_num=`expr $cur_num + 1`
	done
	echo -e "\033[31;1mDONE\033[0m                                                                  \n"
}

function mk_report
{
	echo "3. Making Report file"
	echo -e "\nNO,hostname,Architecture,OS Release,Kernel Release,CPU,Memory,FileSystem,Network,Process,ntp offset,hwclock,log,etc" > $REPORTFILE
	arr_ulist=($(ls -l | grep ^d | grep -v extract | awk '{print $9}' | sort | tr '\n' ' '))
	total_num=${#arr_ulist[@]}
	cur_num=1	
	for i in ${arr_ulist[@]}
	do
		cd $ma_dir/${i}
		echo -ne "Host Name : ${i}                      \n"
		## [ Do MA] ##
		tmp_str="$cur_num,`cat ./collect_sys/kernel/uname_-a |awk '{print $2}'`"
		tmp_str="$tmp_str,`cat ./collect_sys/kernel/uname_-a |awk '{print $12}'`"
		tmp_str="$tmp_str,`cat ./etc/redhat-release`"
		tmp_str="$tmp_str,`cat ./collect_sys/kernel/uname_-a |awk '{print $3}'`"
		
		## [ value get ] ##
	    cpu_use=`grep "Total CPU" ./syscheck.out| awk '{printf "%d%%\n", $5}'`
		if [ $(echo $cpu_use | awk -F "%" '{print $1}') -lt 90 ]; then
			cpu_use=""
		fi
	    mem_use=`cat ./collect_sys/memory/free |egrep "Mem"|tr -dc "0-9, ,\n"|awk '{use=($2-$6)*100/$1}{ printf  "%d%%\n",use}'`
		if [ $(echo $mem_use | awk -F "%" '{print $1}') -lt 90 ]; then
			mem_use=""
		fi

		file_use=`cat ./collect_sys/filesys/df_-h |grep -v Filesystem|egrep "df_|9[0-9]%|100%"|rev|awk '{printf " %s %s",$2,$1}'|rev`

		network_use=`grep "rx_errors" ./collect_sys/networking/*|grep -v -w 0|cut -d"_" -f4|cut -d":" -f1`
		network_unit=""
		network_bond=""
		for j in $(echo $network_use)
		do 
			network_unit=`echo "$network_unit\n$(grep bond etc/sysconfig/network-scripts/ifcfg-${j}|cut -d"=" -f2) (${j}: RX Packet error)"`
			network_bond="${network_bond} $j"
		done
		network_unit=`echo $network_unit | sed '1d'`

		network_info=""
		for j in $(echo $network_bond)
		do
			one=`grep -n -e $(echo $j) collect_sys/networking/ifconfig_-a |cut -d":" -f1`;
			two=$(for k in `grep -n -e "^$" collect_sys/networking/ifconfig_-a | awk -F ":" '{print $1}'`; do if [ $k -gt $one ]; then echo $k; break; fi; done)
			network_info="${network_info} $(sed 's/$/\\n/' collect_sys/networking/ifconfig_-a|sed -n ''"$one"','"$two"'p')" 
			#echo "$one , $two , $network_info"
		done

		process_use=`cat collect_sys/process/ps_auxwww|grep " Z"|grep "<defunct>"|awk '!x[$1]++ {print $0}'`
		process_num=$(cat collect_sys/process/ps_auxwww|grep " Z"|grep "<defunct>"|wc -l)
		if [ $process_num -gt 0 ]; then
			process_num="zombie $process_num"
		else
			process_num=""
		fi
		info_etc="$network_info $process_use"
		### HWCLOCK CHECK
		HWUTIME=$(TZ=Asia/Seoul date -d "`cat collect_sys/general/hwclock`" +%s)
		DATEUTIME=$(TZ=Asia/Seoul date -d "`cat collect_sys/general/date`" +%s)
		
		if [ $HWUTIME -ge $DATEUTIME ]
		then
			let DIFF=$HWUTIME-$DATEUTIME
		else
			let DIFF=$DATEUTIME-$HWUTIME
		fi
		DIFFDAY=0
		DIFFHOUR=0
		let DIFFMINUTE=$DIFF/60
		if [ $DIFFMINUTE -ge 60 ]
		then
			let DIFFHOUR=$DIFFMINUTE/60
			let DIFFMINUTE=$DIFFMINUTE%60
			if [ $DIFFHOUR -ge 24 ]
			then
				let DIFFDAY=$DIFFHOUR/24
				let DIFFHOUR=$DIFFHOUR%24
			fi
		fi
		let DIFFSECOND=$DIFF%60
		HWCLCHK=""	
		if [ $DIFFDAY -lt 1 -a $DIFFHOUR -lt 1 -a $DIFFMINUTE -lt 1 ]
		then
			HWCLCHK=""
		else
			if [ $DIFFDAY -ge 1 ]
			then
				HWCLCHK="${DIFFDAY}d "
			fi
			
			if [ $DIFFHOUR -ge 1 ]
			then
				HWCLCHK="${HWCLCHK} ${DIFFHOUR}h "
			fi
			
			if [ $DIFFMINUTE -ge 1 ]
			then
				HWCLCHK="${HWCLCHK} ${DIFFMINUTE}m ${DIFFSECOND}s"
			fi
		fi

		tmp_str="$tmp_str,$cpu_use,$mem_use,$file_use,\"$network_unit\",$process_num,,$HWCLCHK,,\"$info_etc\""

		## [ Return pre ] ##
		cd - > /dev/null

		## [ Write output file ] ##
		echo -e $tmp_str >> $REPORTFILE
        cur_per=`echo "" | awk -v cur_num=$cur_num -v total_num=$total_num '{printf "%d", cur_num/total_num*100}'`
        per_bar $cur_per
		echo -ne "\b\r"
        cur_num=`expr $cur_num + 1`
	done
	echo -e "\033[31;1mDONE\033[0m                                             \n"
	echo "Report File named \"./extract/report.csv\" has been saved"
}

####### Filtering Log file
cnt=0


################################
#### Printing functions
################################
function check_log(){
	date=$(date -d "`head -1 ./${1}/collect_sys/general/date`" '+%Y%m')
	dateb=$(LANG=C date -d "`head -1 ./${1}/collect_sys/general/date` 1 month ago" '+%b')
	LOGPATH="./${1}/var/log/messages"
	LOGPATHPRE="./${1}/var/log/messages-${date}??"

	echo "########### ${1} #############" > $LOGCHKFILE/${1}.txt
	if [ -f $LOGPATHPRE ]
	then
		if [ -f var/log/*.gz ]
		then
			for j in `ls var/log/${LOGPATHPRE}.gz`
			do
				gzip -d $j
			done
		fi
		cat $LOGPATHPRE |egrep -i '(warning|critical|fail|stop|error|down|retry|Call Trace|abort)' |egrep -v "${FILTERED}" |egrep -v "(${dateb}  [1-4])" >> $LOGCHKFILE/${1}.txt
	fi
	cat $LOGPATH |egrep -i '(warning|critical|fail|stop|error|down|retry|Call Trace|abort)' |egrep -i -v "${FILTERED}" >> $LOGCHKFILE/${1}.txt
	echo "" >> $LOGCHKFILE/${1}.txt
	echo "" >> $LOGCHKFILE/${1}.txt

}

function check_multipath(){
	MPATHPATH="./${1}/collect_sys/devicemapper/multipath_-ll"
	egrep '(offline|failed|faulty)' $MPATHPATH >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "\033[1;31m${i}\033[0m has a problem\n" >> $MPATHCHKFILE
		egrep '(offline|failed|faulty)' $MPATHPATH >> $MPATHCHKFILE
	fi
}

function check_bond(){
	IFCONPATH="./${1}/collect_sys/networking/ifconfig_-a"
	BONDPATH="./${1}/proc/net/bonding"
	cat $IFCONPATH | grep "^bond" >& /dev/null
	if [ $? -eq 0 ]
	then
		ARR_BOND=($(cat ${IFCONPATH} | grep ^bond | awk '{print $1}'| awk -F ":" '{print $1}' | sort -u | tr '\n' ' '))
		for j in ${ARR_BOND[@]}
		do
			cat $BONDPATH/$j | grep down >& /dev/null
			if [ $? -eq 0 ]
			then
				printf "\033[1;31m${1}\033[0m :: \033[1m${j}\033[0m has a problem\n" >> $BONDCHKFILE
				cat $BONDPATH/$j >> $BONDCHKFILE
				echo "" >> $BONDCHKFILE
			fi
		done
	fi
}

function check_nfs(){
	FSTABPATH="./${1}/etc/fstab"
	DFPATH="./${1}/collect_sys/filesys/df_-h"
	cat $FSTABPATH | grep nfs | grep -v "^#" >& /dev/null
	if [ $? -eq 0 ]
	then
		for j in `cat $FSTABPATH | grep nfs | grep -v "^#" | awk '{print $2}'`
		do
			grep $j $DFPATH >& /dev/null
			if [ $? -eq 1 ]
			then
				printf "\033[1;31m## ${1}\033[0m :: The mount point of \033[1m ${j}\033[0m isn't mounted\n" >> $NFSCHKFILE
			fi
		done
	fi
}

function check_ntp(){
	NTPCHKPATH="./${i}/collect_sys/ntp/ntpq_-p"
	cat ${NTPCHKPATH} | egrep -v '(jitter|^==|^\+|^\*)' >& /dev/null
	if [ $? -eq 0 ]
	then
		echo "########${i}########" >> $NTPCHKFILE
		cat ${NTPCHKPATH} | egrep -v '(jitter|^==|\+|^\*)' >> $NTPCHKFILE
	fi
}

function check_daemon_6(){
	DAEMONCHKPATH="./${i}/collect_sys/startup/chkconfig_--list"
	### check kdump
	cat ${DAEMONCHKPATH} | grep kdump | grep 3:off >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} :: " >> $DAEMONCHKFILE
		echo "kdump off" >> $DAEMONCHKFILE
	fi

	### check portmap
	cat ${DAEMONCHKPATH} | grep portmap | grep 3:off >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} :: " >> $DAEMONCHKFILE
		echo "portmap off" >> $DAEMONCHKFILE
	fi

	### check rpcbind
	cat ${DAEMONCHKPATH} | grep rpcbind | grep 3:off >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} :: " >> $DAEMONCHKFILE
		echo "rpcbind off" >> $DAEMONCHKFILE
	fi

	### check ntp
	cat ${DAEMONCHKPATH} | grep "ntpd " | grep 3:off >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} :: " >> $DAEMONCHKFILE
		echo "ntpd off" >> $DAEMONCHKFILE
	fi

	### check ntpdate
	cat ${DAEMONCHKPATH} | grep ntpdate | grep 3:off >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} :: " >> $DAEMONCHKFILE
		echo "ntpdate off" >> $DAEMONCHKFILE
	fi

	### netfs
	cat ${DAEMONCHKPATH} | grep netfs | grep 3:off >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} ::" >> $DAEMONCHKFILE
		echo "netfs off" >> $DAEMONCHKFILE
	fi

}

function check_daemon_7(){
	DAEMONCHKPATH7="./${i}/collect_sys/startup/systemctl_list-unit-files"
	### check kdump
	cat ${DAEMONCHKPATH7} | grep kdump | grep disabled >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} :: " >> $DAEMONCHKFILE
		echo "kdump disabled" >> $DAEMONCHKFILE
	fi

	### check rpcbind
	cat ${DAEMONCHKPATH7} | grep rpcbind | grep disabled >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} :: " >> $DAEMONCHKFILE
		echo "rpcbind disabled" >> $DAEMONCHKFILE
	fi

	### check ntp
	cat ${DAEMONCHKPATH7} | grep ntpd.service | grep disabled >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} :: " >> $DAEMONCHKFILE
		echo "ntpd disabled" >> $DAEMONCHKFILE
	fi

	### check ntpdate
	cat ${DAEMONCHKPATH7} | grep ntpdate | grep disabled >& /dev/null
	if [ $? -eq 0 ]
	then
		printf "${i} :: " >> $DAEMONCHKFILE
		echo "ntpdate disabled" >> $DAEMONCHKFILE
	fi

	### netfs
}

function log_filtering(){
	total_num=`ls -l ./ | grep "^d" | grep -v extract | wc -l`
	cur_num=1
	echo "4. Log Filtering ~"
	for i in `ls -l ./ | grep "^d" | grep -v extract | awk '{print $9}'`
	do
		check_log $i
		check_multipath $i
		check_bond $i
		check_nfs $i
		check_ntp $i
		RHELVER=`cat ./${i}/etc/redhat-release | tr '[a-z]|[A-Z]' ' '| awk '{print $1}' | awk -F "." '{print $1}'`
		echo -ne "Host Name : ${i}           \n"
		if [ $RHELVER -ge 7 ]
		then
			check_daemon_7
		else
			check_daemon_6
		fi
        cur_per=`echo "" | awk -v cur_num=$cur_num -v total_num=$total_num '{printf "%d", cur_num/total_num*100}'`
        per_bar $cur_per
		echo -ne "\b\r"
        cur_num=`expr $cur_num + 1`
	done
	echo -e "\033[31;1mDONE\033[0m                                         \n"
	echo "Check in the \"extract\" directory"

}

clear
file_unzip
echo ""
hostname_check
echo ""
mk_report
echo ""
log_filtering
echo ""
