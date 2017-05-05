#!/bin/bash
NowUnixTime=`date +%s`
function RedisInfoGetValue () {
local redishost=${1}
local redisport=${2}
local rediskey=${3}
local rediscli="/usr/bin/redis-cli"
local redisinfovalue=`${rediscli} -h ${redishost} -p ${redisport} info | grep "^${rediskey}:" | awk -F: '{print $2}' | tr -d ' \r'`
echo ${redisinfovalue}
}
LastSaveUnixTime=`RedisInfoGetValue 127.0.0.1 6381 rdb_last_save_time`
if [[ `echo $((NowUnixTime-LastSaveUnixTime))` -gt 9000 ]];then
   echo "Error: Last Time Bgsave Fail"
else
    echo "Ok: Last Bgsave Time OK"
fi
