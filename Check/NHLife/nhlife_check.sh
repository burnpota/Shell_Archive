#!/bin/bash 

VENDOR=$(dmidecode -t system | egrep '(Manufacturer|Product)' | awk -F ":" '{print $2}' | tr '\n' ' ')
KERNELVER=$(uname -r)
RHELVER=$(cat /etc/redhat-release)
RHELVER2=$(cat /etc/redhat-release | awk '{print $7}' | awk -F "." '{print $1}')
LOG_EXTRACT="(fail|down|error|warn|crit|stop|abort)"
LOG_FILTER="(CIFS VFS|Status code returned|rngd: failed fips test|nsrexexd: page allocation failure)"

CHKSYS="/opt/timegate"					
DIFFDIR="${CHKSYS}/`date +%Y%m`"		
DIFFDIRERR="${DIFFDIR}/err"			
DIFFDIRSYS="${DIFFDIR}/sys"			
DIFFDIRLOG="${DIFFDIR}/log"		

################################
#### Printing functions
################################

function print_ok() {
    printf "[ \033[1;32mOK\033[0m ]\n"
}

function print_up() {
    printf "[ \033[1;32mUP\033[0m ]\n"
}

function print_nok() {
    printf "[ \033[1;31mNOK\033[0m ]\n"
}

function print_down() {
    printf "[ \033[1;31mDOWN\033[0m ]\n"
}

function printf_RED(){
    printf "\033[1;31m${1}\033[0m\n"
}

function printf_GREEN(){
    printf "\033[1;32m${1}\033[0m\n"
}

function printf_YELLO(){
    printf "\033[1;33m${1}\033[0m\n"
}

function printf_BOLD(){
    printf "\033[1m${1}\033[0m"
}

################################
#### Starting the script
################################

function start_script(){
    if [ ! -d $CHKSYS ]
    then
        mkdir -p $CHKSYS
        chmod 600 $CHKSYS
    fi
    if [ ! -d $DIFFDIR ]
    then
        mkdir -p $DIFFDIR
    fi
    if [ ! -d $DIFFDIRERR ]
    then
        mkdir -p $DIFFDIRERR
    fi
    if [ ! -d $DIFFDIRSYS ]
    then
        mkdir -p $DIFFDIRSYS
    fi
    if [ ! -d $DIFFDIRLOG ]
    then
        mkdir -p $DIFFDIRLOG
    fi
}

function start_chksys(){
	clear
    printf "\n\n\n\n########################################\n"
    printf "####    \033[1;32mSystem Check Script\033[0m         ####\n"
    printf "####    \033[1;31mOS Team from Time-Gate(c)\033[0m   ####\n"
    printf "########################################\n\n"
}


################################
#### SYSTEM Information
################################

function system_info(){
    printf_YELLO "#### System Information"
    printf "Host Name      : "
	printf_BOLD "$(hostname)\n"
    printf "OS Version     : "
	printf_BOLD "${RHELVER}\n"
    printf "Kernel Version : "
    printf_BOLD "${KERNELVER}\n"
}


################################
#### Checking CPU status
################################

function sys_cpu(){
    printf_BOLD "Checking CPU Status\n"
    CPUIDLE=$(vmstat | sed -n 3p | awk '{print 100-$15}') 
    printf "   '--- CPU Usage : "
    printf_BOLD " ${CPUIDLE}%%\n"
	echo "CPU usage : ${CPUIDLE}%" > $DIFFDIRSYS/CPU_usage
}


################################
#### Checking Memory status
################################

function sys_mem(){
    printf_BOLD "Checking Memory Space\n"
    MEMTOTAL=$(cat /proc/meminfo | grep MemTotal | awk '{printf "%.f", $2/1024}') 
    MEMUSED=$(cat /proc/meminfo | grep 'MemTotal\|MemFree\|Buffers\|Cached' | awk '{print $2}' | tr '\n' ' ' | awk '{printf "%.f", $1/1024-$2/1024-$3/1024-$4/1024}') 
    printf "   '---  TOTAL Size : "
    printf_RED "${MEMTOTAL}"
    printf "   '---  USING Size : "
	printf_RED "${MEMUSED}"
	echo "Total : ${MEMTOTAL} / Used : ${MEMUSED}" > $DIFFDIRSYS/MEM_usage
}

function sys_swap(){
    printf_BOLD "Checking Swap Space\n"
    SWAPTOTAL=$(cat /proc/meminfo | grep SwapTotal | awk '{printf "%.f", $2/1024}')
    SWAPUSED=$(cat /proc/meminfo | grep 'SwapTotal\|SwapFree' | awk '{print $2}' | tr '\n' ' ' | awk '{printf "%.f", $1/1024-$2/1024}')
    printf "   '---  TOTAL Size : "
    printf_RED "${SWAPTOTAL}"
    printf "   '---  USING Size : "
	printf_RED "${SWAPUSED}"
	echo "Total : ${SWAPTOTAL} / Used : ${SWAPUSED}" >> $DIFFDIRSYS/SWAP_usage
}

################################
#### Checking File System
################################


function filesys_df() {
    printf_BOLD "Checking Disk Usage ....."
    DISKUSAGELI=`df -TPh | sed '1d' | sed 's/%//g' |  awk '$6 > 80{print $1"\t"$6"%"}' | wc -l` 
    if [ $DISKUSAGELI -ge 1 ] 
    then
        print_nok
		printf "   '---"
        df -TPh | sed '1d' | sed 's/%//g' |  awk '$6 > 80{print $1"\t"$6"%"}'
        df -TPh | sed '1d' | sed 's/%//g' |  awk '$6 > 80{print $1"\t"$6"%"}' >> $DIFFDIRSYS/FS_usage
    else
        print_ok
    fi
}

function filesys_mount() {
    printf_BOLD "Checking Mount Point \n"
    ARR_FSTAB=($(cat /etc/fstab | egrep -v '(^#|^$|swap|proc|tmpfs|devpts|sysfs|proc)' | awk '{print $1}' |  tr '\n' ' ')) 
    ARR_VGNAME=($(vgs | sed 1d | awk '{print $1}' | tr '\n' ' '))
    for i in ${ARR_FSTAB[@]} 
    do
        CHKPRE=$(echo ${i} | grep "UUID" | awk -F "=" '{print $2}')
        if [ -z "$CHKPRE" ]
        then
            for j in ${ARR_VGNAME[@]}
            do
                echo ${i} | grep -i $j >& /dev/null
                if [ $? -eq 0 ]
                then
                    MAPVAL=$(echo ${i} | awk -F "/" '{if($3=="mapper")print $0;else print "/"$2"/mapper/"$3"-"$4;}')
                    printf "   '--- %s ..." $MAPVAL
                    cat /etc/mtab | grep $MAPVAL >& /dev/null
			        if [ $? -eq 1 ]
			        then
			            printf_RED "is not mounted"
						echo "${MAPVAL} is not mounted" >> $DIFFDIRERR/FS_not_mounted
			        else
			            print_ok
			        fi
                fi
            done
        else 
            UUIDVAL=$(blkid | grep ${CHKPRE} | awk -F ":" '{print $1}') 
            printf "   '--- %s ..." $UUIDVAL
            cat /etc/mtab | grep $UUIDVAL >& /dev/null 
        	if [ $? -eq 1 ]
	        then
   	        printf_RED "is not mounted"
				echo "${UUIDVAL} is not mounted" >> $DIFFDIRERR/FS_not_mounted
   		    else
   	   	    	print_ok
			fi
        fi
    done
}

function filesys_multipath() {
    printf_BOLD "Checking Multipath \n"
    rpm -qa | grep device-mapper-multipath >& /dev/null 
    if [ $? -eq 1 ] 
    then
        printf_RED "   '--- Multipath not installed"
    else
        multipath -ll | grep "DM multipath kernel driver not loaded" >& /dev/null 
        if [ $? -eq 0 ] 
        then
            printf_RED "   '--- Multipath not configured"
        else
            CHECK_MULTI=$(multipath -ll | wc -l ) 
            if [ $CHECK_MULTI -eq 0 ] 
            then
                printf_RED "   '--- Multipath not Setted up"
            else
				printf "   '--- multipath status : "
				multipath -ll | egrep "(failed|offline|faulty)" >& /dev/null 
				if [ $? -eq 0 ] 
				then
					print_nok
					multipath -ll | egrep '(failed|faulty|offline)' | awk '{print "      \"--- "$2 " \033[1;31m "$3" \033[0m " $4" "$5" "$6" "$7}'
					multipath -ll | egrep "(failed|offline|faulty)" >> $DIFFDIRERR/multipath_status
				else
					print_ok 
				fi
            fi
        fi
    fi
}

################################
#### Checking System Uptime
################################

function chkuptime(){
    printf "uptime : "
    UPTIMECHK=$(uptime | awk -F "," '{print $1}')
	printf_BOLD "${UPTIMECHK}\n"
}

################################
#### Checking Network
################################

function net_ping_test(){
	GWADDR=$(route -n | grep '^0.0.0.0' | awk '{print $2}') 
	printf_BOLD "Checking ping test (wait for seconds) ....."
	PINGRESULT=$(ping -c 4 $GWADDR  | tail -2 | sed '2d') 
	PINGCHECK=$(echo $PINGRESULT | awk '{print $6'}) 
	
	if [ $PINGCHECK == "0%" ]
	then
		print_ok
	else
		print_nok
		echo $PINGRESULT
		echo $PINGRESULT > $DIFFDIRERR/ping_test
	fi
}

function net_drop_count(){
	SYS_NIC_PATH="/sys/class/net" 
	ARR_NIC=($(ls $SYS_NIC_PATH | egrep -v '(lo|pan|virbr|docker|bonding_masters)')) 

	printf_BOLD "Checking NIC STAUTS \n"
	for i in ${ARR_NIC[@]}
	do
		printf "   '-- ${i} status : "
		if [ `cat $SYS_NIC_PATH/$i/operstate` == "up" ] 
		then
		   	print_up
			RX_DROP_COUNT=$(cat $SYS_NIC_PATH/$i/statistics/rx_dropped) 
			TX_DROP_COUNT=$(cat $SYS_NIC_PATH/$i/statistics/tx_dropped) 
			printf "     '--- ${i} checking drop count ....."
			if [ $RX_DROP_COUNT -eq 0 -a $TX_DROP_COUNT -eq 0 ] 
			then
				print_ok
			else
				print_nok
				if [ ! $RX_DROP_COUNT -eq 0 ]
				then
					printf "         '-- RX drop count : "
					printf_RED "${RX_DROP_COUNT}"
					echo "${i} :: RX_Dropped : $RX_DROP_COUNT" >> $DIFFDIRERR/NIC_dropped
				fi

				if [ ! $TX_DROP_COUNT -eq 0 ] 
				then
					printf "         '-- TX drop count : "
					printf_RED "${TX_DROP_COUNT}"
					echo "${i} :: TX_Dropped : $RX_DROP_COUNT" >> $DIFFDIRERR/NIC_dropped
				fi
			fi
		fi
	done
}


################################
#### Checking defunct process
################################

function zombie_pro(){
	printf_BOLD "Checking Zombie process ..... "
	ZOMBIE=$(ps aux | grep defunct | grep -v grep)
	ps aux | grep defuct | grep -v grep >& /dev/null
	if [ $? -eq 0 ]
	then
		print_nok
		echo $ZOMBIE
		echo $ZOMBIE >> $DIFFDIRERR/process_zombie
	else
		print_ok
	fi

}

################################
#### Checking Kdump Status
################################

function kdump_stat(){
	printf "kdump status : "
	if [ $RHELVER2 -ge 7 ] 
	then
		systemctl list-units | grep kdump | grep active >& /dev/null 
		if [ $? -eq 1 ] 
		then
			print_nok
			systemctl list-units | grep kdump | grep failed
			systemctl list-units | grep kdump | grep failed >> $DIFFDIRERR/kdump_status
		else
			print_ok
		fi
	else
		service kdump status | grep not >& /dev/null 
		if [ $? -eq 0 ] 
		then
			print_nok
			service kdump status | grep not 
			service kdump status | grep not >> $DIFFDIRERR/kdump_status
		else
			print_ok
		fi
	fi
}

function kdump_conf(){
	printf "kdump config : "
	cat /etc/kdump.conf | grep "^path /var/crash" >& /dev/null 
	if [ $? -eq 0 ]
	then
		print_ok
	else
		print_nok
		printf "   '--- "
		printf_BOLD "Check /etc/kdump.conf!!"
	fi
}

################################
#### Checking NTP status
################################

function ntp_check(){
	printf_BOLD "   '--- ntpd performance : "
	ntpq -p | grep "No association ID's returned" >& /dev/null 
	if [ $? -eq 0 ]
	then
		print_nok
		printf "      '--- NTP Server is "
		printf_RED "NOT SETTED UP"
	else
		ntpq -p | egrep -v '(jitter|^==|^\+|^\*)' >& /dev/null
		if [ $? -eq 0 ]
		then
			print_nok
			ntpq -p | egrep -v '(jitter|^==|^\+|^\*)'
			ntpq -p | egrep -v '(jitter|^==|^\+|^\*)' >> $DIFFDIRERR/ntpd
		else
			print_ok
		fi
	fi
}

function chrony_check(){
	printf_BOLD "   '--- chronyd performance : "
	CHRONY_CNT=$(chronyc sources | sed -n 1p | awk '{print $6}') 
	if [ $CHRONY_CNT -eq 0 ]
	then
		print_nok
		printf "      '--- NTP Server is "
		printf_RED "NOT SETTED UP"
	else
		chronyc sources | sed '1,3 d' | egrep -v '(\^*|\^+)' >& /dev/null 
		if [ $? -eq 0 ]
		then
			print_nok
			chronyc sources | sed '1,3 d' | egrep -v '(\^*|\^+)' 
			chronyc sources | sed '1,3 d' | egrep -v '(\^*|\^+)' >> $DIFFDIRERR/chrony
		else
			print_ok
		fi
	fi
}

function ntp_status(){
	printf_BOLD "NTP status : "

	netstat -nlpu | egrep "/ntpd|/chronyd" >& /dev/null 
	if [ $? -eq 1 ] 
	then
		print_down
		printf "   '--- NTP daemon is "
		printf_RED "NOT RUNNING"
	else
		print_up
		netstat -nlpu | egrep "/ntpd" >& /dev/null 
		if [ $? -eq 0 ] 
		then
			ntp_check		
		else
			chrony_check		
		fi
	fi
}
################################
#### Checking bonding status
################################

ARR_VIRT_NIC=($(ls /sys/devices/virtual/net | egrep -v '(lo|pan|virbr)')) 

function bonding_chk(){
	printf_BOLD "   '--- Checking ${1} \n"
	printf "      '--- link status : "
	cat /proc/net/bonding/$1 | grep down >& /dev/null 
	if [ $? -eq 0 ]
	then
	    print_nok
		cat /proc/net/bonding/$1 | grep -B1 "MII Status: down" | awk -F ":" '{print $1": \033[1m"$2"\033[0m"}' | sed "s/^/         '--- /g" | sed "s/         '--- MII/            '--- MII/g"
		cat /proc/net/bonding/$1 | grep -B1 "MII Status: down" |awk -F ":" '{print $1": \033[1m"$2"\033[0m"}' | sed "s/^/         '--- /g" | sed "s/         '--- MII/            '--- MII/g" >> $DIFFDIRERR/net_bonding_status
	else
	    print_ok
	fi  
	CNT_BOND_DOWN=$(cat /proc/net/bonding/$1 | grep "Link Failure Count:" | awk '($4>="1"){print $4}' | wc -l)
	printf "      '--- down count : "
	if [ $CNT_BOND_DOWN -ge 1 ]
	then
		print_nok
		cat /proc/net/bonding/$1 | grep -v "Link Failure Count: 0" | grep -B4 "Link Failure Count" | egrep -v '(--|MII Status|Speed|Duplex)' | sed "s/^/         '--- /g" | sed "s/'--- Link Failure Count:/   '--- Link Failure Count:/g" | awk -F ":" '{print $1": \033[1m"$2"\033[0m"}'
		cat /proc/net/bonding/$1 | grep -v "Link Failure Count: 0" | grep -B4 "Link Failure Count" | egrep -v '(--|MII Status|Speed|Duplex)' | sed "s/^/         '--- /g" | sed "s/'--- Link Failure Count:/   '--- Link Failure Count:/g" >> $DIFFDIRERR/net_bonding_down_cnt
	else
		print_ok
	fi
	printf "      '--- Bonding Mode:"
	printf_BOLD "`cat /proc/net/bonding/$1 | grep "Bonding Mode" | awk -F ":" '{print $2}'`\n"
}

function teaming_chk(){
	
	printf_BOLD "   '--- Checking ${1} \n"
	printf "      '--- link status : "
	teamdctl $1 state | grep link: | grep down >& /dev/null 
	if [ $? -eq 0 ]
	then
	    print_nok
		teamdctl $1 state | grep -B2 'link summary: down' | grep -v 'link watches' | sed "s/^/         '---/g" | sed "s/'---      link summary:/     '--- link summary:/g" | sed "s/'---  /'--- Slave Interface: /g" | awk -F ":" '{print $1": \033[1m"$2"\033[0m"}'
		teamdctl $1 state | grep -B2 'link summary: down' | grep -v 'link watches' | sed "s/^/         '---/g" | sed "s/'---      link summary:/     '--- link summary:/g" | sed "s/'---  /'--- Slave Interface: /g" | awk -F ":" '{print $1": \033[1m"$2"\033[0m"}' >> $DIFFDIRERR/net_teaming_status
	else
	    print_ok
	fi
	printf "      '--- down count : "
	CNT_TEAM_DOWN=$(teamdctl $1 state | grep "down count:" | awk '($3>="1"){print $3}' | wc -l)
	if [ $CNT_TEAM_DOWN -ge 1 ]
	then
		print_nok
		teamdctl $1 state | grep -v "down count: 0" | grep -B6 "down count:" | egrep -v '(link watches|link summary|instance|name|link)'| sed "s/^/         '---/g" | sed "s/'---        down count:/     '--- down count:/g" | sed "s/'---  /'--- Slave Interface: /g" | awk -F ":" '{print $1": \033[1m"$2"\033[0m"}'
		teamdctl $1 state | grep -v "down count: 0" | grep -B6 "down count:" | egrep -v '(link watches|link summary|instance|name|link)'| sed "s/^/         '---/g" | sed "s/'---        down count:/     '--- down count:/g" | sed "s/'---  /'--- Slave Interface: /g" | awk -F ":" '{print $1": \033[1m"$2"\033[0m"}' >> $DIFFDIRERR/net_teaming_down_cnt
	else
		print_ok
	fi
	printf "      '---"
	printf_BOLD "`teamdctl $1 state | grep " runner:" `\n"
}

function nic_dulplex(){
	printf_BOLD "Bonding/Teaming check\n"
	VIRT_NIC_CNT=${#ARR_VIRT_NIC[@]}
	if [ $VIRT_NIC_CNT -eq 0 ] 
	then
		printf "   '--- "
		printf_RED "There are none bonding/teaming"
	else
		for i in ${ARR_VIRT_NIC[@]}
		do
			NIC_DEV_TYPE=$(cat /etc/sysconfig/network-scripts/ifcfg-${i} | grep "DEVICETYPE" | awk -F "=" '{print $2}') 
			if [ $NIC_DEV_TYPE == "Bond" ]
			then
				bonding_chk $i 
			else
				teaming_chk $i 
			fi
		done
	fi
}

################################
#### Checking OS Firewall
################################

function firewall_chk(){
	printf_BOLD "firewall status\n"

	if [ $RHELVER2 -ge 7 ] 
	then
		printf "   '--- firewalld active : "
		systemctl status firewalld | grep Active: | grep " active" >& /dev/null 
		if [ $? -eq 1 ] 
		then
			printf "[ \033[1;32mDOWN\033[0m ]\n"
		else
    		printf "[ \033[1;31mUP\033[0m ]\n"
		fi
		
		printf "   '--- firewalld enabled : "
		systemctl list-unit-files | grep firewalld | grep enable >& /dev/null 
		if [ $? -eq 0 ] 
		then
			printf "[ \033[1;31mENABLE\033[0m ]\n"
		else
    		printf "[ \033[1;32mDISABLED\033[0m ]\n"
		fi
	else
		printf "   '--- iptables active : "
		CHK_IPTABLE=$(iptables -nL | wc -l) 
		if [ $CHK_IPTABLE -eq 8 ] 
		then
			printf "[ \033[1;32mDOWN\033[0m ]\n"
		else
    		printf "[ \034[1;31mUP\033[0m ]\n"
		fi
		printf "   '--- iptabled enabled : "
		chkconfig --list iptables | egrep '(3:on|5:on)' >& /dev/null 
		if [ $? -eq 0 ] 
		then
			printf "[ \033[1;31mENABLED\033[0m ]\n"
			printf "      '--- \033[1;32m"
			chkconfig --list iptables | egrep '(3:on|5:on)' | awk '($5 == "3:on"){print $5}($7 == "5:on"){print $7}' | tr '\n' ' '
			printf "\033[0m\n"
		else
    		printf "[ \033[1;32mDISABLED\033[0m ]\n"
		fi
	fi
}


################################
#### Checking Log
################################

DATE_MONTH=`date | awk '{print $2}'`
function log_chk(){
    cat /var/log/messages | egrep -i $LOG_EXTRACT | grep $DATE_MONTH | egrep -v "${LOG_FILTER}" > $DIFFDIRLOG/log_messages 
	cat /var/log/secure > $DIFFDIRLOG/log_secure 
    dmesg | egrep -i $LOG_EXTRACT > $DIFFDIRLOG/log_dmesg 
    printf_BOLD "Checking messages\n"
    printf "(Press Enter)"
    read
	cat $DIFFDIRLOG/log_messages |more
    echo ==========================================
	printf_BOLD "Checking secures\n"
	printf "(Press Enter)"
	read
	cat $DIFFDIRLOG/log_secure | more 
    echo ==========================================
    printf_BOLD "Checking dmesg\n" 
    printf "(Press Enter)"
    read
	cat $DIFFDIRLOG/log_dmesg | more
}


################################
#### Start script
################################

start_script
start_chksys
system_info

printf "\n"
printf_YELLO "#### Checking CPU"
	sys_cpu

printf "\n"
printf_YELLO "#### Checking MEMORY "
	sys_mem
	sys_swap

printf "\n"
printf_YELLO "#### Checking FileSystem"
	filesys_df
	filesys_mount
	filesys_multipath

printf "\n"
printf_YELLO "#### System Uptime"
	chkuptime

printf "\n"
printf_YELLO "#### Network Status"
	net_ping_test
	net_drop_count

printf "\n"
printf_YELLO "#### Checking Process"
	zombie_pro

printf "\n"
printf_YELLO "#### Checking KDUMP"
	kdump_stat
	kdump_conf

printf "\n"
printf_YELLO "#### Checking NTP"
	ntp_status

printf "\n"
printf_YELLO "#### Checking Bonding"
	nic_dulplex

printf "\n"
printf_YELLO "#### Checking firewall"
	firewall_chk

printf "\n"
printf_YELLO "#### Checking Logs"
	log_chk
