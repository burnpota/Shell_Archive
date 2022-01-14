#!/bin/bash 

###Variables about path or file name
CASEPATH=`pwd`
CASECSV=$CASEPATH/CaseList.csv #csv file name
LISTTXT='caselist.txt' 
BEAUTY=$CASEPATH/beauty.sh
ACCINFO=$CASEPATH/account_info

###Variables about Temporary files
TMP_DIR=$CASEPATH/tmp_$$
TMP_LIST=$TMP_DIR/tmp.caselist.$$
TMP_DIFF=$TMP_DIR/tmp.diff.$$
TMP_FAIL=$TMP_DIR/tmp.fail.$$
TMP_FAIL2=$TMP_DIR/tmp.fail2.$$
TMP_LOGIN=$TMP_DIR/tmp.login.$$


###Variables about Account information
source $ACCINFO
ARR_ACCNO=($(cat ${ACCINFO} | awk -F ":" '{print $1}' | awk -F "=" '{print $2}'))


###Variables about SCP transmission
RUSER='root'
RADDR='10.1.0.177'
RPATH='/data/REPO/casefile'

### Functions for exiting with removing tmp files
function exiting(){
	rm -rf $TMP_DIR
	exit
}

########################
### Functions for Print
########################

function print_login(){
printf "
==================================
  \033[1;31mREDAHT CASE ARRAGNEMENT SCRIPT\033[0m
  	  ver 1.3.0
  	  by OS team
	  Taemoo Heo
==================================\n"

read -p "REDAHT ID : " USERID
printf  "REDHAT PW : "
read -s USERPASS
printf  "\n"

HASHTRY=`echo ${USERID}:${USERPASS} | sha512sum | awk '{print $1}'`
}

function print_download(){
printf "
=== Start Donwloading Cases ===\n"

}

function print_end(){
printf "\033[1;31mWell Done\033[0m\n"
}

function print_OK(){
	printf "[\033[1;32mOK\033[0m]\n"
}

function print_fail(){
	printf "[\033[1;31mFail\0rr[0m]\n"
}

##########################
### Functions for Checking
##########################

function check_csv(){
	if [ ! -f $CASECSV ]
	then
		printf "
ERROR
You need this file ::: %s\n" $CASECSV
		exiting
	fi

	###Removing Quates in CSV File
	sed -i 's/^"//g' $CASECSV
	sed -i 's/"$//g' #CASECSV
}

function check_account(){
	ACCOUNTNU=`sed '1d' $CASECSV | awk -F "\",\"" '{print $1}' | uniq`
	ACC_BOOL=0
	for i in ${ARR_ACCNO[@]}
	do	
		if [ $i == $ACCOUNTNU ]
		then
			GET_ACCINFO=`cat $ACCINFO | grep $i`
			DIRPATH=`echo $GET_ACCINFO | awk -F ":" '{print $3}'`
			CASEDIR="${CASEPATH}/${DIRPATH}"
			HASHVAL=`echo $GET_ACCINFO | awk -F ":" '{print $2}'`
			ACC_BOOL=1
		else
			continue
		fi
	done

	if [ $ACC_BOOL -eq 0 ]
	then
		printf "
ERROR
Undefined Account number
Check %s\n" $CASECSV
	exiting
	fi
}

function check_login_ok(){
	if [ "${HASHTRY}" != "${HASHVAL}" ]
	then
		printf "\n\033[1;31mLogin Failed!!!!!!!\033[0m\nCheck your ID or PW\n"
		exiting
	else
		printf "\n\033[1;32mLogin Success!!\033[0m\n"
	fi
}

function check_dir(){
	if [ ! -d $CASEDIR ]
	then
		mkdir $CASEDIR
	fi
}

function check_new_case(){
	if [ `cat $TMP_DIFF | wc -l ` -eq 0 ]
	then
		printf "\nNOTICE\nThere are no new closed cases\n"
		exiting
	fi
}

function check_down_ok(){
	if [ ! $? -eq 0 ]
	then
		echo $CASEADDR >> $1
		print_fail
	else
		print_OK
	fi
}

function check_failed(){
	while [ -f $TMP_FAIL ]
	do
		echo "${i} retry..."
		for j in `cat $TMP_FAIL`
		do
		do_download_case $TMP_FAIL $TMP_FAIL2	
		done

		if [ -f $TMP_FAIL2 ]
		then
			mv $TMP_FAIL2 $TMP_FAIL
		else
			mv $TMP_FAIL ${TMP_FAIL}.ok
		fi
	done
}

##############################
### Functions for making files
##############################

function mk_tmpdir(){
	mkdir $TMP_DIR
	chmod 700 $TMP_DIR
}

function mk_listtxt(){
	ls -1 $CASEDIR/*.html 2> /dev/null | awk -F "/" '{print $NF}' | awk -F "." '{print $1}' | sort > $CASEDIR/$LISTTXT
}

function mk_tmpfiles(){
	sed '1d' $CASECSV | grep -v 'Waiting on' | awk -F "\",\"" '{print $2}' | sort > $TMP_LIST
	diff $CASEDIR/$LISTTXT $TMP_LIST | sed -n '/>/p' | awk -F " " '{print $2}' > $TMP_DIFF
}

########################
### Functions for action
########################

function do_download_case(){
for i in `cat $1`
do
	printf "${i} Download..."
	CASEADDR=`awk -F "\",\"" -v CASE=$i '{if($2==CASE){print $14}}' $CASECSV`
	curl -u ${USERID}:${USERPASS} $CASEADDR -o $TMP_DIR/${i}.html &> /dev/null
	
	check_down_ok $2
done
}

function do_beauty(){
	for i in `cat $TMP_DIFF`
	do
		printf "%s is being arranged..." $i
		$BEAUTY $TMP_DIR/${i}.html
	if [ $? -eq 0 ]
	then
		print_OK
	else
		print_fail
	fi
done
}

function do_scp_transmission(){
#### DO NOT USE this function
#### IF YOU DO NOT COPY YOUR
#### SSH KEYGEN TO SCP SERVER
RDIR=`echo $CASEDIR | awk -F "/" '{print $NF}'`
	printf "CASEs are transmiting to %s..." $RADDR
	scp  $TMP_DIR/*html $RUSER@$RADDR:$RPATH/$RDIR &> /dev/null
	if [ -$? -eq 0 ]
	then
		print_OK
	else
		print_fail
	fi
}

function do_arrange(){
mv $TMP_DIR/*html $CASEDIR
mv $TMP_LIST $LISTTXT
mv $CASECSV $CASEDIR
}

######################
#### Start Script ####
######################

check_csv
mk_tmpdir
check_account
print_login
check_login_ok
check_dir
mk_listtxt
mk_tmpfiles
check_new_case
print_download
do_download_case $TMP_DIFF $TMP_FAIL
check_down_ok
do_beauty
#do_scp_transmission
do_arrange
print_end
exiting

