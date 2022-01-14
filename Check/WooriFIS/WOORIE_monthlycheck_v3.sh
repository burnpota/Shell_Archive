#!/bin/bash 

VENDOR=$(dmidecode -t system | egrep '(Manufacturer|Product)' | awk -F ":" '{print $2}' | tr '\n' ' ')
KERNELVER=$(uname -r)
RHELVER=$(cat /etc/redhat-release)
RHELVER2=$(cat /etc/redhat-release | awk '{print $7}' | awk -F "." '{print $1}')

LOG_EXTRACT="(fail|down|error|warn|critical|stop|abort)"
LOG_FILTER="(CIFS VFS|Status code returned|rngd: failed fips test|nsrexexd: page allocation failure|Tracker-WARNING|Agent Manager)"
LOG_DISK="(DISK I/O|ext[*]|xfs)"


CHKSYS=/opt/timegate
DIFFDIR=$CHKSYS/`date +%Y%m`
DIFFDIRERR="${DIFFDIR}/err"
DIFFDIRSYS="${DIFFDIR}/sys"
DIFFDIRLOG="${DIFFDIR}/log"
DIFFDIROLD=$CHKSYS/`date -d'1 month ago' +%Y%m`
DIFFETC=$DIFFDIR/ADMIN_ETC_PERM
DIFFETCOLD=$DIFFDIROLD/ADMIN_ETC_PERM
DIFFPASS=$DIFFDIR/ADMIN_PASSWD
DIFFPASSOLD=$DIFFDIROLD/ADMIN_PASSWD
DIFFGROUP=$DIFFDIR/ADMIN_GROUP
DIFFGROUPOLD=$DIFFDIROLD/ADMIN_GROUP
DIFFROOT=$DIFFDIR/ADMIN_ROOT
DIFFROOTOLD=$DIFFDIROLD/ADMIN_ROOT
DIFFROUTE=$DIFFDIR/NETWORK_ROUTE
DIFFROUTEOLD=$DIFFDIROLD/NETWORK_ROUTE

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
		mkdir $CHKSYS
		chmod 600 $CHKSYS
	fi
	if [ ! -d $DIFFDIR ]
	then
		mkdir $DIFFDIR
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

function start_chkold(){
	OLDBOOL=0
	if [ ! -d $DIFFDIROLD ]
	then
		printf_RED "\n#### There are no old diff files on your system ####"
		printf_RED "#### Check ${CHKSYS} if it is not first execution ####\n"
		OLDBOOL=1
	fi
}

function start_chksys(){
	printf "\n\n\n\n########################################\n"
	printf "####  \033[1;32mWoori FIS System Check Script\033[0m ####\n"
	printf "####    \033[1;31mOS Team from Time-Gate(c)\033[0m   ####\n"
	printf "########################################\n\n"
	printf_YELLO "#### System Information"
	printf "Host Name      : $(hostname)\n"
	printf "Server Model   :${VENDOR}\n"
	printf "OS Version     : ${RHELVER}\n" 
	printf "Kernel Version : ${KERNELVER}\n"
}

################################
#### Diff Set up functions
################################

function diff_etc(){
	ls -aRl /etc | awk '{print $1" " $2" "$3" "$4" "$5" "$9}' > $DIFFETC
}

function diff_passwd(){
	cat /etc/passwd |  > $DIFFPASS
}

function diff_group(){
	cat /etc/group > $DIFFGROUP
}

function diff_root(){
	ls -aRl /root/ | awk '{print $1" " $2" "$3" "$4" "$5" "$9}' > $DIFFROOT
}

function diff_route(){
	netstat -rn > $DIFFROUTE
}

function diff_save(){
	diff_etc
	diff_passwd
	diff_group
	diff_root
	diff_route
	chmod 600 -R $DIFFDIR
}

function comp_diff(){
	#comp_etc [old] [current]
	DIFFFILE=$(diff ${1} ${2})
	if [ -z "${DIFFFILE}" ]
	then
		print_ok
	else
		print_nok
		printf "   '--- "
		printf_RED "There are some modified or added values since last month"
		printf_RED "        Check below results"
		diff $1 $2 | sed 's/^/         /g'
	fi
}

function chk_old(){
	if [ $OLDBOOL -eq 1 ]
	then
		printf "[ None OLD ]\n"
	else
		comp_diff $1 $2
	fi
}

################################
#### Checking File System Status
################################

function filesys_df() {
    printf_BOLD "Checking Disk Usage ....."
    DISKUSAGELI=`df -TPh | sed '1d' | sed 's/%//g' |  awk '$6 > 80{print $1"\t"$6"%"}' | wc -l` 
    if [ $DISKUSAGELI -ge 1 ] 
    then
        print_nok
        df -TPh | sed '1d' | sed 's/%//g' |  awk '$6 > 80{print $1" : \033[1;31m "$6"%\033[0m"}' | sed "s/^/   '--- /g"
        df -TPh | sed '1d' | sed 's/%//g' |  awk '$6 > 80{print $1" : "$6"%"}' >> $DIFFDIRSYS/FS_usage    
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
					break
                else  
                    printf "   '--- %s ..." ${i}
                    cat /etc/mtab | grep ${i}  >& /dev/null
                    if [ $? -eq 1 ]
                    then
                        printf_RED "is not mounted"
                        echo "${i} is not mounted" >> $DIFFDIRERR/FS_not_mounted
                    else
                        print_ok
                    fi
					break
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
		printf "   '--- "
        printf_RED "Multipath not installed"
    else
        multipath -ll | grep "DM multipath kernel driver not loaded" >& /dev/null
        if [ $? -eq 0 ]
        then
			printf "   '--- "
            printf_RED "Multipath not configured"
        else
            CHECK_MULTI=$(multipath -ll | wc -l )
            if [ $CHECK_MULTI -eq 0 ] 
            then
				printf "   '--- "
                printf_RED "Multipath not Setted up"
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
#### Checking Admin Files
################################

function check_diff(){
	printf_BOLD "Checking Integracy of Admin Files\n"
	if [ $OLDBOOL -eq 1 ]
	then
		printf "   '--- "
		printf_RED "None OLD"
	else
		printf "   '--- "
		printf_BOLD "/etc :"
		comp_diff $DIFFETCOLD $DIFFETC
		printf "   '--- "
		printf_BOLD "/root :"
		comp_diff $DIFFROOTOLD $DIFFROOT
		printf "   '--- "
		printf_BOLD "/etc/passwd :"
		comp_diff $DIFFPASSOLD $DIFFPASS
		printf "   '--- "
		printf_BOLD "/etc/group : "
		comp_diff $DIFFGROUPOLD $DIFFGROUP
	fi
}

################################
#### Checking Network System
################################

function net_drop_count(){
    SYS_NIC_PATH="/sys/class/net" 
    ARR_NIC=($(ls $SYS_NIC_PATH | egrep -v '(lo|pan|virbr|docker|bonding_masters)')) 

    printf_BOLD "Checking NIC STATUS \n"
    for i in ${ARR_NIC[@]}
    do
        printf "   '---  ${i} status : "
        if [ `cat $SYS_NIC_PATH/$i/operstate` == "up" ] 
        then
            print_up
            RX_DROP_COUNT=$(cat $SYS_NIC_PATH/$i/statistics/rx_dropped) 
            TX_DROP_COUNT=$(cat $SYS_NIC_PATH/$i/statistics/tx_dropped) 
            printf "      '--- ${i} checking drop count : "
            if [ $RX_DROP_COUNT -eq 0 -a $TX_DROP_COUNT -eq 0 ] 
            then
                print_ok
            else
                print_nok
                if [ ! $RX_DROP_COUNT -eq 0 ]
                then
                    printf "         '--- RX drop count : "
                    printf_RED "${RX_DROP_COUNT}"
                    echo "${i} :: RX_Dropped : $RX_DROP_COUNT" >> $DIFFDIRERR/NIC_dropped
                fi

                if [ ! $TX_DROP_COUNT -eq 0 ] 
                then
                    printf "         '--- TX drop count : "
                    printf_RED "${TX_DROP_COUNT}"
                    echo "${i} :: TX_Dropped : $RX_DROP_COUNT" >> $DIFFDIRERR/NIC_dropped
                fi
            fi
        fi
    done
}

ARR_VIRT_NIC=($(ls /sys/devices/virtual/net | egrep -v '(lo|pan|virbr)')) 

function bonding_chk(){
	printf "   '--- "
    printf_BOLD "Checking ${1} \n"
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
}

function teaming_chk(){

	printf "   '--- "
    printf_BOLD "Checking ${1} \n"
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
}

function net_duplex(){
    printf_BOLD "Checking Bonding/Teaming\n"
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


function net_route(){
	printf_BOLD "Checking Route Status : "
	chk_old $DIFFROUTEOLD $DIFFROUTE
}

################################
#### Checking System Resouce
################################

function sys_cpu(){
	printf_BOLD "Checking CPU Status\n"
	CPUIDLE=$(vmstat | sed -n 3p | awk '{print $15}')
	CPUCORE=$(grep -c processor /proc/cpuinfo)
	ARR_LOAD=($(uptime | awk -F "load average: " '{print $2}' | tr ',' ' '))
	printf "   '--- CPU Core : "
	printf_BOLD "${CPUCORE}\n"
	echo " CPU core : ${CPUCORE}" >> $DIFFDIRSYS/cpu_load_balace
	printf "   '--- Load Average : "
	CHKBOOL=0
	for i in $ARR_LOAD
	do
		if [ `echo $i | awk '{printf "%d", $1}'` -gt $CPUCORE ]
		then
			CHKBOOL=1
		fi
	done
	if [ $CHKBOOL -eq 1 ]
	then
		print_nok
		echo -e "      '--- Value : \033[1;31m${ARR_LOAD[@]}\033[0m" 
		echo "${ARR_LOAD[@]}" >> $DIFFDIRSYS/cpu_load_balace
	else
		print_ok
		echo -e "      '--- Value : ${ARR_LOAD[@]}" 
		echo "${ARR_LOAD[@]}" >> $DIFFDIRSYS/cpu_load_balace
	fi

	printf "   '--- CPU Idle : "
	if [ $CPUIDLE -ge 80 ]
	then
		print_ok
		echo "      '--- Value : ${CPUIDLE}%"
		echo "${CPUIDLE}%" >> $DIFFDIRSYS/cpu_idle
	else
		print_nok
		echo -e "      '--- Value : \033[1;31m${CPUIDLE}%\033[0m\n"
		echo "${CPUIDLE}%" >> $DIFFDIRSYS/cpu_idle
	fi
}

function sys_mem(){
	printf_BOLD "Checking Memory Space : "
	MEMTOTAL=$(free -m | sed -n '/^Mem/p' | awk '{print $2}')
	MEMFREE=$(cat /proc/meminfo | grep 'MemFree\|Buffers\|Cached' | awk '{print $2}' | tr '\n' ' ' | awk '{printf "%.0f", $1/1024+$2/1024+$3/1024}')
	MEMPERC=$(echo "${MEMTOTAL} ${MEMFREE}" | awk '{printf "%.1f", $2 / $1 * 100}')
	
	if [ `echo $MEMPERC | awk '{printf "%d", $1}'` -ge 5 ]
	then
		print_ok
		echo "   '--- Free Space is ${MEMPERC}%"
		echo "${MEMPERC}%" >> $DIFFDIRSYS/mem_free
	else
		print_nok
		echo -e "   '--- Free Space is \033[1;31m${MEMPERC}%\033[0m"
		echo "${MEMPERC}%" >> $DIFFDIRSYS/mem_free
	fi
}

function sys_swap(){
	printf_BOLD "Checking Swap Space ....."
	SWAPTOTAL=$(free -m | sed -n '/^Swap/p' | awk '{print $2}')
	SWAPUSED=$(cat /proc/meminfo | grep 'SwapTotal\|SwapFree' | awk '{print $2}' | tr '\n' ' ' | awk '{printf "%.f", $1/1024-$2/1024}')
	SWAPPERC=$(echo "${SWAPTOTAL} ${SWAPUSED}" | awk '{printf "%.1f", $2 / $1 * 100}')
	if [ `echo $SWAPPERC | awk '{printf "%d", $1}'` -ge 3 ]
	then
		print_nok
		echo "   '--- Swap Usage is ${SWAPPERC}%" 
		echo "${SWAPPERC}%" >> $DIFFDIRSYS/swap_usage
	else
		print_ok
		echo "   '--- Swap Usage is ${SWAPPERC}%"
		echo "${SWAPPERC}%" >> $DIFFDIRSYS/swap_usage
	fi
}

function sys_process(){
	TMPPROC=/tmp/$$
	printf_BOLD "Checking Process Status : "
	cat /proc/*/status | grep State | sort -u > $TMPPROC
	grep 'Z' $TMPPROC &> /dev/null
	if [ $? -eq 0 ]
	then
		print_nok
		grep "R " $TMPPROC | sed "s/^/   '--- /g"
		grep "S " $TMPPROC | sed "s/^/   '--- /g"
		grep "Z " $TMPPROC | sed "s/^/   '--- /g"
		printf "      '--- "
		ps aux | grep defunct 
		ps aux | grep defunct >> $DIFFDIRERR/zombie
	else
		print_ok
		grep "R " $TMPPROC | sed "s/^/   '--- /g"
		grep "S " $TMPPROC | sed "s/^/   '--- /g"
	fi
	
}

################################
#### Checking uptime
################################

function chkuptime(){
	printf_BOLD "uptime : "
	uptime | awk -F "," '{print $1}'
}

################################
#### Checking LOG
################################

DATE_MONTH=`date | awk '{print $2}'` 
function log_chk(){ 
    cat /var/log/messages | egrep -i $LOG_EXTRACT | grep $DATE_MONTH | egrep -v "${LOG_FILTER}" > $DIFFDIRLOG/log_messages  
    dmesg | egrep -i $LOG_EXTRACT > $DIFFDIRLOG/log_dmesg  
    printf_BOLD "Checking dmesg\n"  
    printf "(Press Enter)" 
    read 
    cat $DIFFDIRLOG/log_dmesg | more 
    echo ========================================== 
    printf_BOLD "Checking messages\n" 
    printf "(Press Enter)" 
    read 
    cat $DIFFDIRLOG/log_messages |more 
} 


start_chksys
start_chkold
start_script
diff_save

printf_YELLO "\n#### 1. File System ####"
filesys_df
filesys_mount
filesys_multipath

printf_YELLO "\n#### 2. Admin Files ####"
check_diff

printf_YELLO "\n#### 3. Network ####"
net_drop_count
net_duplex
net_route

printf_YELLO "\n#### 4. System Performance ####"
sys_cpu
sys_mem
sys_swap
sys_process

printf_YELLO "\n#### 5. Check Uptime ####"
chkuptime

printf_YELLO "\n#### 6. Check Log ####"
log_chk
printf "\n"

