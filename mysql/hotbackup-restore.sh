#!/bin/bash
## Xtrabackup Database Backup Restore

##

WORK_PATH=`pwd`
MEMORY="2G"
DATE=`date +%F_%H-%M`
MYSQL_PATH="/data/mysql/var"

#远程数据库用户信息
MYSQL_HOST='127.0.0.1'
MYSQL_USER='dbmanager'
MYSQL_PASSWD='eyDqNafZ6pq39Rah'


function help ()
{

        echo 'Usage:
        $CMDNAME [OPTION]... [hotbak_restore.sh <OPTION>]
        Options:
        -all                                数据库完全备份文件.
        -incr                               数据库增量备份文件.
	-tab				    要导出的库名和表名文件.	
        --help                              显示帮助.
        -h                                  显示帮助.'
}

function error_msg ()
{


	MSG=${1}
	echo -e "\033[41;37;5m ERROR: ${MSG} \033[0m"
}

function incr_restore()
{


	local COMPLETE=${1}
	local INCREASE=${2}

	if [ "${INCREASE##*.}" == "tgz" ];then
		INCREASE_PATH=${INCREASE%.tgz}
	else
		INCREASE_PATH=${INCREASE%.tar.gz}
	fi

	if [ -n "${WORK_PATH}" ]; then
		_PATH=${WORK_PATH}
	else
		echo "unknown error"
		exit 1
	fi

	if [ -d "${MYSQL_PATH}" ]; then
		[ -n "`/sbin/pidof -s mysqld`" ] && /etc/init.d/mysqld stop
		mv ${MYSQL_PATH} ${MYSQL_PATH%/*}/var.${DATE}
		mkdir ${MYSQL_PATH}
	else
		mkdir ${MYSQL_PATH}
	fi

	tar zxvfi ${COMPLETE} -C ${MYSQL_PATH}
	tar zxvfi ${INCREASE} -C ${_PATH}

	check_version
	${XTRABACKUP} --prepare --use-memory=${MEMORY} --target-dir=${MYSQL_PATH}
	if [ $? -ne 0 ];then
		error_msg "完整备份数据异常,请检查..."
		exit 1
	fi
	${XTRABACKUP} --prepare --use-memory=${MEMORY} --target-dir=${MYSQL_PATH} --incremental-dir=${_PATH}/${INCREASE_PATH}
	echo "${XTRABACKUP} --prepare --use-memory=${MEMORY} --target-dir=${MYSQL_PATH} --incremental-dir=${_PATH}/${INCREASE_PATH}"
	if [ $? -ne 0 ]; then
		error_msg "增量备份数据异常,请检查..."
		exit 1
	fi
	${XTRABACKUP} --prepare --use-memory=${MEMORY} --target-dir=${MYSQL_PATH}
	if [ $? -ne 0 ]; then
		error_msg "创建事务日志文件失败..."
		exit $?
	fi
	chown -R mysql.mysql ${MYSQL_PATH}
	rm -rf ${_PATH}/${INCREASE_PATH}
}

function complete_restore()
{


	local COMPLETE=${1}
	if [ -d "${MYSQL_PATH}" ]; then
		[ -n "`/sbin/pidof -s mysqld`" ] && /etc/init.d/mysqld stop
		mv ${MYSQL_PATH} ${MYSQL_PATH%/*}/var.${DATE}
		mkdir ${MYSQL_PATH}
	else
		mkdir ${MYSQL_PATH}
	fi

	tar zxvfi ${COMPLETE} -C ${MYSQL_PATH}
	check_version
	${XTRABACKUP} --prepare --use-memory=${MEMORY} --target-dir=${MYSQL_PATH}
	if [ $? -ne 0 ]; then
		error_msg "备份数据异常,请检查..."
		exit 1
	fi
	${XTRABACKUP} --prepare --use-memory=${MEMORY} --target-dir=${MYSQL_PATH}
	if [ $? -ne 0 ]; then
		error_msg "创建事务日志文件失败..." && exit 1
	fi

	chown -R mysql.mysql ${MYSQL_PATH}
}

function check_version ()
{
	# process: check_version function
	# Syntax:  check_version <path>
	# Author:  Felix.li
	# Returns:
	#       N/A

	BAK_TYPE=$(awk -F: '/last_lsn/ {print $2}' ${MYSQL_PATH}/xtrabackup_checkpoints)
	VERSION=$(${MYSQL_PATH%/var}/bin/mysqladmin -V|awk '{split($5,ver,".");print ver[1]"."ver[2]}')
	MYSQL_VER=$(${MYSQL_PATH%/var}/bin/mysqladmin -V|awk '{print $5}')

	if [ -n "${BAK_TYPE}" ];then
		BAKFILE_VER="Backup file from mysql 5.1 version or others"
	else
		BAKFILE_VER="Backup  file from mysql 5.5 version or others"
	fi

	if [ -n "${BAK_TYPE}" -a ${VERSION} == "5.1" ];then
		XTRABACKUP="xtrabackup_51"
	elif [ -z "${BAK_TYPE}" -a ${VERSION} == "5.5" ];then
		XTRABACKUP="xtrabackup_55"
	else
		error_msg "警告: 数据库版本与数据库备份文件不一致,${BAKFILE_VER}. and local mysql version is ${MYSQL_VER}." && exit 1
	fi

	NEW_VALUE=$(awk -F[:M] '/innodb_data_file_path/{print $2}' /etc/my.cnf)
	OLD_VALUE=$(awk -F[:M] '/innodb_data_file_path/{print $2}' ${MYSQL_PATH}/backup-my.cnf)
	if [ "${NEW_VALUE}" -ne "${OLD_VALUE}" ];then
		error_msg "ERROR: my.cnf中的ibdata表空间值跟之前不一致..." && exit 1
	fi

}

function dump ()
{


	TABLIST=${1}
	BAK_DATE=$(date '+%Y%m%d_%H%M%S')
	if [ -f ${TABLIST} ];then
		cat ${TABLIST}| while read BAK_TABLE
		do
			TABLE_NAME=`echo ${BAK_TABLE}|awk '{print $1}'`
			DBNAME=$(find /data/mysql/var -name "${TABLE_NAME}.frm" |awk -F"/" '/'"${TABLE_NAME}"'/{print $5}')
			mysqldump -h127.0.0.1 -udbmanager -peyDqNafZ6pq39Rah -R --triggers ${DBNAME} ${BAK_TABLE} >${BAK_DATE}.sql
			mysql -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWD} -e "create database \`${DBNAME}\`"
			mysql -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWD} ${DBNAME} < ${BAK_DATE}.sql
		done
	else
		echo "${TABLIST} is not exist"
		exit $?
	fi
}

if [ "$#" -gt 0 ]; then
        for ((i=1;i<=$#;i++));do
                eval a[$i]=\$$i
        done

        for ((i=1;i<=${#a[@]};i++));do
                case "${a[$i]}" in
                         --help|-\?|-h)
				help
                                break
                                ;;
                        -all)
                                ((i++))
                                COMPLETE_FILE="${a[$i]}"
                                continue
                                ;;
                        -incr)
                                ((i++))
                                INCR_FILE="${a[$i]}"
                                continue
                                ;;
                        -tab)
                                ((i++))
                                TABLE_OPT="${a[$i]}"
                                continue
                                ;;
                        *)
                                help
                esac
        done

	if [ `uname -r|grep -c el6.x86_64` -eq 1 ];then
		yum -y install perl-Time-HiRes perl-DBD-MySQL
		rpm -i http://122.226.74.168/percona-xtrabackup-2.1.3-608.rhel6.x86_64.rpm
	else
		if [ ! `rpm -qa | grep 'percona-xtrabackup-2.0.1-446.rhel5'` ] ;then
			rpm -qa |grep -qi xtrabackup | xargs rpm -e >/dev/null 2>&1
			rpm -i --nodeps http://122.226.74.168/percona-xtrabackup-2.0.1-446.rhel5.x86_64.rpm
		fi
	fi

	if [ -n "${COMPLETE_FILE}" -a -n "${INCR_FILE}" ];then
		incr_restore ${COMPLETE_FILE} ${INCR_FILE}
		/etc/init.d/mysqld start && exit 0 || exit 1
		wait
		[ -n "${TABLE_OPT}" ] && dump ${TABLE_OPT}
	elif [ -n "${COMPLETE_FILE}" ];then
		complete_restore ${COMPLETE_FILE}
		/etc/init.d/mysqld start --skip-slave-start && exit 0 || exit 1
		wait
		[ -n "${TABLE_OPT}" ] && dump ${TABLE_OPT}
	fi

else
        help
fi


