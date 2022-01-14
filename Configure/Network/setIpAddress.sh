#!/bin/bash

MACADDR=$1
IPADDR=$2
NETMASK=$3
GATEWAY=$4

function CHK_BOND {
	ip a | egrep -i 'bond|team' >& /dev/null
	[ $? -eq 0 ] && echo "bondings or Teamings have been set up : [ False ]" &&  exit 1
}

function MAP_MAC_DEV {
	DEVFIND=$(nmcli dev show | egrep 'DEVICE|HWADDR' | grep -i -B 1 -w ${MACADDR} | head -1 | awk '{print $2}')
	[ "${DEVFIND}" == "" ] && echo "Invalid Mac Address : [ False ]" && exit 1
}

function CHK_DEV_CON {
	DEVSTAT=$(nmcli dev | grep -i ${DEVFIND} | awk '{print $3}')
	[ $DEVSTAT == "disconnected" ]	&& nmcli dev connect "${DEVNAME}"
	DEVNAME=$(nmcli dev show ${DEVFIND} | grep "GENERAL.CONNECTION" | awk '{for(i=2;i<=NF;i++){printf $i" "}}' | sed 's/ $//g')
	
}

function CAL_NETMASK {
	PREFIX=0
	CHK_NET_VALID=0
	for i in `echo $NETMASK | awk -F "." '{print $1" "$2" "$3" "$4}'`
	do
		[ $i -eq 0 ] && continue
		if [ $CHK_NET_VALID -eq 1 ] || [ $i -gt 255 ]
		then
			echo "Invalid Netmask address : [ False ]"
			exit 1
		fi
		c=0
		sumbit=0
		for j in {7..0}
		do
			bit=$(( 2 ** ${j} ))
			sumbit=$(( $sumbit + $bit ))
			c=$(( $c + 1 ))
	
			if [ $sumbit -eq $i ]
			then
				PREFIX=$(( $PREFIX + $c ))
				[ ! $sumbit -eq 255 ] && CHK_NET_VALID=1
				break
			elif [ $sumbit -lt $i ]
			then
				continue
			else
				echo "Invalid Netmask address : [ False ]"
				exit 1
			fi
		done
#		[ ! $i -eq 0 ] && echo "Invalid Netmask address : [ False ]" && exit 1
#		PREFIX=$(( $PREFIX + $c ))
	done
}

function MOD_IPADDR {
	nmcli con mod "${DEVNAME}" ipv4.addresses ${IPADDR}/${PREFIX} ipv4.gateway ${GATEWAY} ipv4.method manual
	nmcli con down "${DEVNAME}"
	nmcli con up "${DEVNAME}"
}


function CHK_ADAPTION {
	ARR_IP_INFO=($(nmcli con show "${DEVNAME}" | egrep 'ipv4.addresses|ipv4.gateway' | awk '{print $2}' | tr '\n' ' '))
	CHK_IPADDR=$(echo ${ARR_IP_INFO[0]} | awk -F "/" '{print $1}')
	CHK_NETMASK=$(echo ${ARR_IP_INFO[0]} | awk -F "/" '{print $2}')
	CHK_GATEWAY=$(echo ${ARR_IP_INFO[1]})

	echo "Inserting IP address"
	echo -n "Result : "
	nmcli con show -a | grep "${DEVNAME}" >& /dev/null
	[ $? -eq 0 ] && CHKUPBOOL=1 
	if [ "${CHK_IPADDR}" == "${IPADDR}" ] && [ "${CHK_NETMASK}" == "${PREFIX}" ] && [ "${CHK_GATEWAY}" == "${GATEWAY}" ] && [ -n $CHKUPBOOL ]
	then
		echo "[ True ]"
		exit 0
	else
		echo " [ False ]"
		exit 1
	fi
}

CHK_BOND
CAL_NETMASK 
MAP_MAC_DEV 
CHK_DEV_CON
MOD_IPADDR 
CHK_ADAPTION


