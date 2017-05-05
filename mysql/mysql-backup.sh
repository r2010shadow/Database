#!/bin/bash


mysql_config_file=$1
. /etc/init.d/functions

PATH=$PATH:/data/mysql/bin
export PATH

# 保留备份的天数
DAY=10

PORT=$(awk -F"=" '$1~/\[mysqld\]/,$FNR {if ($1~/port/) {print $2;exit}}' $mysql_config_file  | xargs)
USER="dbmanager"
MYSQLHOST="127.0.0.1"
PASSWORD="eyDqNafZ6pq39Rah"

IOPS=30
USE_MEM="10M"
DATE=$(date '+%F_%H-%M')
HOUR=$(date +%H)
BACKUP_PATH="/data/backup/database_${PORT}"
LOG_FILE="/var/log/xtrabackup_${PORT}.log"
MYSQL_LOG="/var/log/mysql_${PORT}.log"
HOST=$(/sbin/ifconfig | grep -E '([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)' | awk '{print $2}' | cut -d":" -f2 | grep -E "^10\.?\.")
LAST_ALL_LOG="/var/log/last_${PORT}.log"

PID_FILE="/tmp/hotbak_inc_mysql_${PORT}"
LOCK_FILE="/var/lock/subsys/xtrabackup_${PORT}"

function out_log ()
{

	if [ -n "$1" ]; then
		_PATH="$1"
	else
		echo "unknown error"
		echo -e "wrong\nunknown error" > ${MYSQL_LOG}
		exit
	fi

	[ ! -f ${LOG_FILE} ] && touch "${LOG_FILE}"
	echo -e "[$(date +%Y-%m-%d' '%H:%M:%S)] ${_PATH}" >> "${LOG_FILE}"
}

function del_bak ()
{

	for dbfile in `find "${1}/" -name "[0-9]*.tar.gz" -type f -mtime +${DAY}`; do
		out_log "delete from ${dbfile}"
		rm -f ${dbfile}
	done
}

if ! rpm -q percona-xtrabackup > /dev/null 2>&1;then
    if [ `uname -r|grep -c el6.x86_64` -eq 1 ];then
            yum -y install perl-Time-HiRes perl-DBD-MySQL
            rpm -ivh http://122.226.74.168/percona-xtrabackup-2.1.3-608.rhel6.x86_64.rpm
    else
        rpm -q xtrabackup-1.6.4-313.rhel5 >/dev/null && rpm -e xtrabackup-1.6.4-313.rhel5
        rpm -q percona-xtrabackup-2.0.0-417.rhel5 >/dev/null && rpm -e percona-xtrabackup-2.0.0-417.rhel5
        rpm -q percona-xtrabackup-2.0.1-446.rhel5  >/dev/null || rpm -ivh --nodeps http://122.226.74.168/percona-xtrabackup-2.0.1-446.rhel5.x86_64.rpm >/dev/null
    fi
fi


if [ ! -d "$BACKUP_PATH" ]; then
	out_log "mkdir -p ${BACKUP_PATH}"
	mkdir -p ${BACKUP_PATH}
	out_log "chown -R nobody.nobody ${BACKUP_PATH}"
	chown -R nobody.nobody ${BACKUP_PATH}
fi

[ ! -f $PID_FILE ] && touch ${PID_FILE}
_PID=`cat ${PID_FILE}`
if [ `ps ax|awk '{print $1}'|grep -v grep|grep -c "\b${_PID}\b"` -eq 1 ] && [ -f ${LOCK_FILE} ]; then
        echo -n $"xtrabackup process already exist."
        echo -e 'wrong\nxtrabackup process already exist.' >${MYSQL_LOG}
        exit
else
        echo $$ >${PID_FILE}
        touch ${LOCK_FILE}
fi

function all_back() {
		DB_NAME=("$HOST"_"$DATE"_"$PORT")
		echo 'all'
		out_log "cd ${BACKUP_PATH}"
		cd ${BACKUP_PATH}
		out_log "innobackupex-1.5.1 ${BACKUP_PATH} --use-memory=${USE_MEM} --throttle=${IOPS} --host=${MYSQLHOST} --user=${USER} --port=${PORT} --password=${PASSWORD} --stream=tar --no-lock 2>>${LOG_FILE} | gzip - > ${BACKUP_PATH}/${DB_NAME}.tar.gz"
		innobackupex-1.5.1 ${BACKUP_PATH} --use-memory=${USE_MEM} --throttle=${IOPS} --host=${MYSQLHOST} --user=${USER} --port=${PORT} --password=${PASSWORD} --stream=tar --no-lock 2>>${LOG_FILE} | gzip - > ${BACKUP_PATH}/${DB_NAME}.tar.gz

		out_log "tar zxfi ${BACKUP_PATH}/${DB_NAME}.tar.gz xtrabackup_checkpoints"
		tar zxfi ${BACKUP_PATH}/${DB_NAME}.tar.gz xtrabackup_checkpoints

		RETVAL=$?

		if	[ ${RETVAL} -eq 0 -a `tail -50 "${LOG_FILE}" | grep -ic "\berror\b"` -eq 0 ]; then
			del_bak "${BACKUP_PATH}"
			echo -n $"Complete Hot Backup"
			success
			echo
			echo -e "ok\n${DB_NAME}.tar.gz" > ${MYSQL_LOG}
			echo -e "ok\n${DB_NAME}.tar.gz" > ${LAST_ALL_LOG}
			rm -f ${LOCK_FILE}
		else
			out_log "[ERROR] error: xtrabackup failure"
			echo -n $"Complete Hot Backup"
			failure
			echo
			echo -e "wrong\n$(tail -50 "${LOG_FILE}" | grep -i "\berror\b" | sed -n '1p')" > ${MYSQL_LOG}
			echo -e "wrong\n${DB_NAME}.tar.gz" > ${LAST_ALL_LOG}
			rm -f ${LOCK_FILE}
		fi
}

function inc_back {
		CHECKPOINT=$(awk '/to_lsn/ {print $3}' ${BACKUP_PATH}/xtrabackup_checkpoints 2>/dev/null)
		DB_NAME=("$HOST"_"$DATE"_"$PORT""-increase")
		echo "inc"

		if [ ! -e "${BACKUP_PATH}/xtrabackup_checkpoints" ];then
                out_log "xtrabackup_checkpoints does not exist"
                all_back
                exit 0
        fi

	if [ $(mysqladmin -u${USER} -p${PASSWORD} -h${MYSQLHOST} version |awk '/Server version/{split($3,array,".");print array[1]array[2]}') -eq 55 ]; then
    	    XTRABACKUP="xtrabackup_55"
    	fi
    	out_log "${XTRABACKUP} --backup --throttle=${IOPS} --target-dir=${BACKUP_PATH}/${DB_NAME} --incremental-lsn=${CHECKPOINT} >>${LOG_FILE} 2>&1"
    	${XTRABACKUP} --backup --throttle=${IOPS} --target-dir=${BACKUP_PATH}/${DB_NAME} --incremental-lsn=${CHECKPOINT} >>${LOG_FILE} 2>&1
    	RETVAL=$?
    	out_log "cd ${BACKUP_PATH}"
    	cd ${BACKUP_PATH}
    	out_log "tar zcfi ${DB_NAME}.tar.gz ${DB_NAME} >/dev/null 2>>${LOG_FILE}"
    	tar zcfi "${DB_NAME}.tar.gz" "${DB_NAME}" >/dev/null 2>>${LOG_FILE}
    	out_log "rm -rf ${DB_NAME}"
    	rm -rf ${DB_NAME}

    	if  [ ${RETVAL} -eq 0 -a `tail -50 "${LOG_FILE}" | grep -ic "\berror\b"` -eq 0 ]; then
    	    del_bak "${BACKUP_PATH}"
    	    echo -n $"Incremental Hot Backup"
    	    success
	    echo
    	    echo -e "ok\n${DB_NAME}.tar.gz" >${MYSQL_LOG}
    	    rm -f ${LOCK_FILE}
    	else
    	    echo -n $"Incremental Hot Backup"
    	    failure
    	    echo
    	    echo -e "wrong\n$(tail -50 "${LOG_FILE}" | grep -i "\berror\b" | sed -n '1p')" >${MYSQL_LOG}
        rm -f ${LOCK_FILE}
    	fi
}

if [ "${HOUR}" -eq "4" ];then
	all_back
else
	inc_back
fi
