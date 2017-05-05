#!/bin/bash

PATH="/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/data/mysql/bin:/usr/local/webserver/php/bin:/root/bin:/data/mysql/
bin"
export PATH
LocalInnerIP=$(ifconfig|grep -E "([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})" | awk -F" " '{print $2}' | cut -d":" -f2 | grep -E "^192\.|^10\.")
ssdb_conf_file="/data/ssdbconfig/ssdb.conf"
[ ! -f ${ssdb_conf_file} ] && (echo "Error: ssdb not install" ;exit)
Port=$(grep -v "#" $ssdb_conf_file | grep "port" | awk '{print $2}')
Host=$(grep -v "#" $ssdb_conf_file | grep "ip" | awk '{print $2}')
TimeStamp=$(date '+%Y%m%d_%H%M%S')
BackupPath="/data/backup/ssdb_${Port}"
BackupFile="${LocalInnerIP}_${TimeStamp}_${Port}.tgz"
TmpDumpFolder="${BackupPath}/${TimeStamp}"
LogFile="/var/log/ssdbbak_${Port}.log"


function ssdb_backup ()
{
	/data/ssdb/ssdb-dump ${Host} ${Port} ${TmpDumpFolder} > /dev/null 2>&1 
	if [ $? -ne 0 ];then
		echo "ssdb-dump fail." > ${LogFile}
		exit
	else
		cd ${BackupPath}
		tar zcf ${BackupPath}/${BackupFile} ${TimeStamp} > /dev/null 2>&1 
		if [ $? -ne 0 ];then
			echo "tar fail." > ${LogFile}
			exit
		fi
	fi
	echo "ok" > ${LogFile}
}

touch ${LogFile}
> ${LogFile}
[ ! -d ${BackupPath} ] && mkdir -p ${BackupPath}
[ -d ${TmpDumpFolder} ] && rm -rf ${TmpDumpFolder}
ssdb_backup
[ -d ${TmpDumpFolder} ] && rm -rf ${TmpDumpFolder}
[ -f "${BackupPath}/${BackupFile}" ] && echo "${BackupFile}" >> ${LogFile}

