#!/bin/bash

RHELVER=$(cat /etc/redhat-release | awk '{print $7}' | awk -F "." '{print $1}')
FILTERED="(debug1:|Libgcrypt|slice|Monitoring|SQLAnywhere|maxpatrl|EMF|sendmail|SAP...|CROND|ptymonitor|Temperature|Could not obtain|vmware-modconfig|vsftpd|PAM|Veritas|avrd|tldd|AgentFramwork|VCS ERROR V|ltid|automount|pbrun|Basis|This host is not entitled to run Veritas Storage Foundation|MTIOCGET failed on VTL_|ioctl error on VTL|sgaSol|polltracking|businessobjects|boe_|PERC H730 Mini|smhMonitor|Connection reset by peer|Failed publickey for sliida from|IPv6|rpcbind*warning\: cannot open|NTPCheck \: reach shift register something wrong|BPM_EMS_FAIL_|VxVM vxdmp|INFO|VCS CRITICAL V|restricted-command|PERC H710 Mini|MQSeries|NAS-monitor|root check failed|FailedPassword|PBFail|bpjava-msvc|notice\:|infoi|errorlog.|postfix|PHY_UPDOWN|LINK_UPDOWN|vpnserv|amanda|gpagent|Stopping User Slice|sendmail)"


function print_ok() {
    printf "[ OK ]\n"
}

function print_up() {
    printf "[ UP ]\n"
}

function print_nok() {
    printf "[ NOK ]\n"
}

function print_down() {
    printf "[ DOWN ]\n"
}

RHEL7_UPDATE_PACKAGE=(bind-utils-9.11.4-16.P2.el7_8.6.x86_64 \
dbus-1.10.24-14.el7_8.x86_64 \
kernel-3.10.0-1160.21.1.el7.x86_64 \
kernel-headers-3.10.0-1160.21.1.el7.x86_64 \
kernel-devel-3.10.0-1160.21.1.el7.x86_64 \
kernel-tools-3.10.0-1160.21.1.el7.x86_64 \
kernel-tools-libs-3.10.0-1160.21.1.el7.x86_64 \
bpftool-3.10.0-1160.21.1.el7.x86_64 \
perf-3.10.0-1160.21.1.el7.x86_64 \
python-perf-3.10.0-1160.21.1.el7.x86_64 \
libarchive-3.1.2-14.el7_7.x86_64 \
libX11-1.6.7-3.el7_9.x86_64 \
net-snmp-utils-5.7.2-49.el7_9.1.x86_64 \
openssl-1.0.2k-21.el7_9.x86_64 \
squid-3.5.20-17.el7_9.4.x86_64 \
sudo-1.8.23-10.el7_9.1.x86_64 \
rear-2.4-11.el7.x86_64 \
grub2-2.02-0.87.el7_9.6.x86_64 \
tar-1.26-35.el7.x86_64 \
rsyslog-8.24.0-55.el7.x86_64 \
)

RHEL7_RPM=($(for i in ${RHEL7_UPDATE_PACKAGE[@]};do COUNT=$(echo $i | awk -F "." '{print $1}' | tr -cd '-' | wc -m); echo $i | awk -v count=$COUNT -F "-" '{if($1=="java"){print $1"-"$2"-"$3}else{for(j=1;j<=count;j++){print $j}}}' | tr '\n' '-';echo ""; done|sed 's/\-$//g'))

RHEL6_UPDATE_PACKAGE=(bind-utils-9.8.2-0.68.rc1.el6_10.7.x86_64 \
ipmitool-1.8.15-3.el6_10.x86_64 \
kernel-2.6.32-754.35.1.el6.x86_64 \
kernel-devel-2.6.32-754.35.1.el6.x86_64 \
kernel-doc-2.6.32-754.35.1.el6.noarch \
kernel-headers-2.6.32-754.35.1.el6.x86_64 \
kernel-firmware-2.6.32-754.35.1.el6.noarch \
kernel-abi-whitelists-2.6.32-754.35.1.el6.noarch \
perf-2.6.32-754.35.1.el6.noarch \
python-perf-2.6.32-754.35.1.el6.noarch \
libX11-1.6.4-4.el6_10.x86_64 \
net-snmp-utils-5.5-60.el6_10.2.x86_64 \
openssl-1.0.1e-59.el6_10.x86_64 \
sudo-1.8.6p3-29.el6_10.4.x86_64 \
zsh-4.3.11-11.el6_10.x86_64 \
)

RHEL6_RPM=($(for i in ${RHEL6_UPDATE_PACKAGE[@]};do COUNT=$(echo $i | awk -F "." '{print $1}' | tr -cd '-' | wc -m); echo $i | awk -v count=$COUNT -F "-" '{if($1=="java"){print $1"-"$2"-"$3}else{for(j=1;j<=count;j++){print $j}}}' | tr '\n' '-' ;echo ""; done | sed 's/\-$//g'))

function check7_update() {
	rpm -qa > /tmp/2021_update
	printf "Checking RHEL7 Updated Packages \n"
	for i in ${RHEL7_RPM[@]}
	do
		cat /tmp/2021_update | grep "^${i}" >& /dev/null
		if [ $? -eq 0 ]
		then
			printf "   '--- ${i} : "
			AA=$(echo ${RHEL7_UPDATE_PACKAGE[@]} | tr ' ' '\n' | grep "^${i}")
			cat /tmp/2021_update | grep "${AA}" >& /dev/null
			if [ $? -eq 0 ]
			then
				print_ok
			else
				print_nok
			fi
		fi
	done 
	check_procps_ng
}

function check_procps_ng() {
	printf "   '--- procps_ng : "
	PRO_VER=`cat /tmp/2021_update | grep "procps-ng-3.3.10" | awk -F "-" '{print $4}' | awk -F "." '{print $1}'`
	if [ $PRO_VER -ge 17 ]
	then
		print_ok
	else
		print_nok
	fi
	
}
function check6_update() {
	rpm -qa > /tmp/2021_update
	printf "Checking RHEL6 Updated Packages \n"
	for i in ${RHEL6_RPM[@]}
	do
		cat /tmp/2021_update | grep "^${i}" >& /dev/null
		if [ $? -eq 0 ]
		then
			printf " '--- ${i} : "
			AA=$(echo ${RHEL6_UPDATE_PACKAGE[@]} | tr ' ' '\n' | grep "^${i}")
			cat /tmp/2021_update | grep "${AA}" >& /dev/null
			if [ $? -eq 0 ]
			then
				print_ok
			else
				print_nok
			fi
		fi
	done
}

function update_chk() {
	if [ $RHELVER -eq 7 ]
	then
		check7_update
	else
		check6_update
	fi
}

function kernel_chk() {
	KERNVER=$(uname -r)
	printf "   '--- "
	uname -r | tr '\n' ' '
	printf " : "
	if [ $RHELVER -eq 7 ]
	then
		if [ "${KERNVER}" == "3.10.0-1160.21.1.el7.x86_64" ]
		then
			print_ok
		else
			print_nok
		fi
	else
		if [ "${KERNVER}" == "2.6.32-754.35.1.el6.x86_64" ]
		then
		print_ok
		else
			print_nok
		fi
	fi
}

function kdump_chk() {
	printf "   '--- "
	if [ $RHELVER -eq 7 ]
	then
		KDUMP_STAT=$(systemctl status kdump | grep Active: | awk '{print $2}')
		if [ $KDUMP_STAT == "active" ]
		then
			print_ok
		else
			print_nok
		fi
	else
		service kdump status | grep not >& /dev/null
		if [ $? -eq 0 ]
		then
			print_nok
		else
			print_ok
		fi
	fi
}
function filesys_mount() {
#    printf "Checking Mount Point \n"
    ARR_FSTAB=($(cat /etc/fstab | egrep -v '(^#|^$|swap|proc|tmpfs|devpts|sysfs|proc)' | awk '{print $2}' |  tr '\n' ' ')) 
	for i in ${ARR_FSTAB[@]}
	do
       	printf "   '--- %s : " $i
		df | grep $i >& /dev/null
		if [ $? -eq 0 ]
		then
			print_ok
		else
			print_nok
		fi
	done

}


function filesys_multipath() {
#    printf "Checking Multipath \n"
    rpm -qa | grep device-mapper-multipath >& /dev/null 
    if [ $? -eq 1 ] 
    then
        printf "   '--- Multipath not installed \n"
    else
        multipath -ll | grep "DM multipath kernel driver not loaded" >& /dev/null 
        if [ $? -eq 0 ] 
        then
            printf "   '--- Multipath not configured\n"
        else
            CHECK_MULTI=$(multipath -ll | wc -l ) 
            if [ $CHECK_MULTI -eq 0 ] 
            then
                printf "   '--- Multipath not Setted up\n"
            else
                printf "   '--- multipath status : "
                multipath -ll | egrep "(failed|offline|faulty)" >& /dev/null 
                if [ $? -eq 0 ] 
                then
                    print_nok
                    multipath -ll | egrep '(failed|faulty|offline)' | awk '{print "      \"--- "$2" "$3" "$4" "$5" "$6" "$7}'
                else
                    print_ok 
                fi  
            fi  
        fi  
    fi  
}

function ntp_check(){
    ntpq -p | grep "No association ID's returned" >& /dev/null
    if [ $? -eq 0 ]
  	then
        print_nok
   	    printf "     '--- NTP Server is NOT SETTED UP\n"
 	else
        ntpq -p | egrep -v '(jitter|^==|^\+|^\*)' >& /dev/null
        if [ $? -eq 0 ]
        then
            print_nok
            ntpq -p 
		else
            print_ok
            ntpq -p
		fi
    fi
}

function ntp_rhel_check(){
    printf "   '--- NTP status : "
	if [ $RHELVER -eq 7 ]
	then
		systemctl status ntpd | grep Active: | grep inactive >& /dev/null
		if [ $? -eq 0 ]
		then
			print_nok
			printf "      '--- NTP daemon is NOT RUNNING\n"
		else
			ntp_check
		fi
	else
		service ntpd status | grep stopped >& /dev/null
		if [ $? -eq 0 ]
		then
			print_nok
			printf "      '--- NTP daemon is NOT RUNNING\n"
		else
			ntp_check
		fi
	fi
}


ARR_VIRT_NIC=($(ls /proc/net/bonding/ 2> /dev/null))

function bonding_chk(){
    printf "   '--- Checking ${1} : "
    cat /proc/net/bonding/$1 | grep down >& /dev/null
    if [ $? -eq 0 ]
    then
        print_nok
        cat /proc/net/bonding/$1 | grep -B1 "MII Status: down" | awk -F ":" '{print $1": "$2}' | sed "s/^/         '--- /g" | sed "s/         '--- MII/            '--- MII/g"
    else
        print_ok
    fi
}

function nic_dulplex(){
#    printf "Bonding check\n"
    VIRT_NIC_CNT=${#ARR_VIRT_NIC[@]}
    if [ $VIRT_NIC_CNT -eq 0 ]
    then
        printf "   '--- "
        printf "There are none bonding\n"
    else
        for i in ${ARR_VIRT_NIC[@]}
        do
               bonding_chk $i
        done
    fi
}

function log_messages(){
	cat /var/log/messages | egrep -i '(warn|crit|fatal|err|down|fail|abort|Call Trace)' | egrep -v "${FILTERED}"
}


### Config for 2021 update

function rhcs_7_config(){
	cat /tmp/2021_update | grep ^pacemaker >& /dev/null
	if [ $? -eq 0 ]
	then
		pcs config | grep "fence_ipmi" >& /dev/null
		if [ $? -eq 0 ]
		then
			printf "   '--- Check RHEL7 lanplus option : "
			pcs config | grep "lanplus=\"on\"" >& /dev/null
			if [ $? -eq 0 ]
			then
				print_nok
				pcs config | grep "lanplus=\"on\""
			else
				print_ok
			fi
		else
			printf "\n"
			printf "   '--- This is VMware Environment \n"
		fi
	else
		printf "    '--- This is not RHCS \n"
	fi
}

function rhcs_6_config(){
	cat /tmp/2021_update | grep cman >& /dev/null
	if [ $? -eq 0 ]
	then
		cat /etc/cluster/cluster.conf | grep ipmilan >& /dev/null
		if [ $? -eq 0 ]
		then
			printf "   '--- Check RHEL6 lanplus option : "
			cat /etc/cluster/cluster.conf | grep "lanplus=\"on\"" >& /dev/null
			if [ $? -eq 0 ]
			then
				print_nok
			cat /etc/cluster/cluster.conf | grep "lanplus=\"on\""
			else
				print_ok
			fi
		else
			printf "\n"
			printf "   '--- This is not use fence_ipmilan \n"
		fi
	else
		printf "    '--- This is not RHCS \n"
	fi
}

function dell_blacklist(){
	HARD_VEN=`dmidecode -t 1 | grep Manufacturer | awk '{print $2}'`
	if [ $HARD_VEN == "Dell" ]
	then
		lsmod | egrep '^i7core_edac|^edac_core' >& /dev/null
		if [ $? -eq 0 ]
		then
			print_nok
		else
			print_ok
		fi
	else
		printf "   '--- This is not Dell Server \n"
	fi
}

printf "\n"
printf "#### Checking Update \n"
	update_chk

printf "\n"
printf "#### Checking Kernel Ver \n"
	kernel_chk

printf "\n"
printf "#### Checking Kdump Daemon \n"
	kdump_chk

printf "\n"
printf "#### Checking FileSystem \n"
    filesys_mount

printf "\n"
printf "#### Checking Multipath \n"
    filesys_multipath

printf "\n"
printf "#### Checking NTP \n"
    ntp_rhel_check

printf "\n"
printf "#### Checking Bonding \n"
    nic_dulplex

printf "\n"
printf "#### System Uptime \n"
    uptime

printf "\n"
printf "#### Checking RHCS lanplus \n"
if [ $RHELVER -eq 7 ]
then
	rhcs_7_config
else
    rhcs_6_config
fi

printf "\n"
printf "### Checking Dell module blacklist \n"
	dell_blacklist

printf "\n"
read -p "(press Enter)"

printf "\n"
printf "#### Checking Log \n"
    log_messages | more

