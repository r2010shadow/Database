#!/bin/bash
## Redis备份


PATH="/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/data/mysql/bin:/usr/local/webserver/php/bin:/root/bin:/data/mysql/bin"
export PATH

redis_conf_file=$1
[ -f $redis_conf_file ] || (echo "redis not install";exit 1)
redis_dir=$(awk '$1~/dir/{print $2}' $redis_conf_file)
PORT=$(awk '$1~/port/{print $2}' $redis_conf_file)
dump_file=$(awk '$1~/dbfilename/{print $2}' $redis_conf_file)
config_file="/data/config"
#备份天份
DAY=3
RedisLog="/var/log/redis_${PORT}.log"
NowDate=$(date '+%Y%m%d_%H%M%S')
BackPath="/data/backup/redisbase_$PORT"
LogFile="/var/log/redisbak_$PORT.log"
PRIVITE_IP="$(/sbin/ifconfig | grep -E '([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)' | awk '{print $2}' | cut -d":" -f2 | grep -E "^10\.?\.")"

echo $redis_dir
echo $PORT


function out_log ()
{

        #       N/A

        if [ -n "$1" ]; then
                _PATH="$1"
        else
                echo "unknown error"
                exit 1
        fi

        [ ! -f ${LogFile} ] && touch "${LogFile}"
        echo -e "[$(date +%Y-%m-%d' '%H:%M:%S)] ${_PATH}" >> "${LogFile}"
}

function del_bak()
{

    echo $1
        for dbfile in `find "${1}/" -name "[0-9]*.tgz" -type f -mtime +${DAY}`; do
                out_log "delete from ${dbfile}"
                rm -f ${dbfile}
        done
}



[ ! -d "${BackPath}" ] && mkdir -p ${BackPath}
if [ -f ${dump_file} ];then
    Start_Time=`date '+%Y%m%d%H%M%S'` && sleep 1&&redis-cli -p $PORT bgsave
    i=1
    while true;do
        Update_Time=$(ls --full-time ${dump_file} |awk '{print $6$7}'| sed 's/-//g;s/://g' | awk -F. '{print $1}')
        if [ $Start_Time -le $Update_Time ];then
            break
        else
            sleep 1
        if (($i>=300));then
            echo -e "wrong\nbgsave failer" > $RedisLog
            exit 0
        else
            ((i++))
        fi

        fi
    done
else
    echo -e "wrong\nnot exist dumpfile" > $RedisLog && exit 9
fi

cd ${BackPath}
[ ! -f ${RedisLog} ] && touch ${RedisLog}
tar zcf ${PRIVITE_IP}_${NowDate}_${PORT}.tgz  ${dump_file} $config_file  2>${RedisLog}
[ $? -eq 0 ] && echo -e "ok\n${PRIVITE_IP}_${NowDate}_${PORT}.tgz" >${RedisLog} || echo -e "wrong\ntar fail" >${RedisLog}

for DelFile in `find ${BackPath}/ -type f -name "*.rdb"`;do
    if [ -f ${DelFile} ];then
        out_log "rm -f ${DelFile}"
        rm -f ${DelFile}
    fi
done
del_bak ${BackPath}

