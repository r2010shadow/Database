#!/bin/bash
#coding=utf8

#
Inner_ip=$(ifconfig|grep -E "([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})" | awk -F" " '{print $2}' | cut -d":" -f2 | grep -E "^192\.|^10\.")
Red(){ 
	echo -ne "\033[31m"$1"\033[0m\n" 
}
Green() {
	echo -ne "\033[32m"$1"\033[0m\n"
}

check_nmap(){
	/bin/rpm -qa|grep nmap >/dev/null 2>&1
	if [ $? -eq 0 ];then
		Green "OK \t $Inner_ip \t nmap已经安装"
	else
		Red "Error \t $Inner_ip \t nmap未安装，现在安装。。。"
		yum -y install nmap >/dev/null 2>&1
	fi
}

check_port(){
	local progressname="$1"
	local progressport="$2"
	/usr/bin/nmap -sS -p $2 127.0.0.1 |grep -A1 "STATE" |awk '{print $2}'|grep "open" >/dev/null 2>&1
	if [ $? -eq 0 ];then
		Green "OK \t $Inner_ip \t $1服务 \t $2端口 \t 连接正常"
	else
		Red "Error \t $Inner_ip \t $1服务 \t $2端口 \t 连接异常，请认真检查"
	fi
}

check_zabbix(){
	/bin/rpm -qa|grep zabbix >/dev/null 2>&1
	status=$(echo $?)
	if [ $status -eq 0 ];then
		Green "OK \t $Inner_ip \t zabbix-agent \t zabbix已经安装"
	else
		Red "Error \t $Inner_ip \t zabbix-agent \t zabbix未安装，请认真检查"
	fi
	[ `curl -s http://10.0.5.216/zabbix/uapi.php?host=${Inner_ip} |awk -F',' '{for(i=1;i<=NF;i++) print $i}'|grep status|awk -F":" '{print $2}'|tr -d '"'` == "ok"  ] && Green "OK \t $Inner_ip \t zabbix-agent \t zabbix已经添加" || Red "Error \t $Inner_ip \t zabbix-agent \t zabbix未添加，请认真检查"
}

# check_opentime(){
	# config=/data/config/om_config.xml
	# serverid=$(cat $config |awk -F'<' '{print $3}'|awk -F'>' '{print $2}')
	# local_time=$(cat $config |awk -F'<' '{print $9}'|awk -F'>' '{print $2}')
	# platform_time=$(curl -s http://opgame.uuzu.com/api/newserver/listbyserver?server_id=$serverid |awk -F',' '{for(i=1;i<=NF;i++) print $i}' |grep "first_opentime"|awk -F':' '{print $2}'|awk -F'"' '{print $2}')
	# if [ $platform_time == "${local_time}" ];then
		# Green "OK \t $Inner_ip \t 开服时间 \t 本地和数据中心匹配"
	# else
		# Red "Error \t $Inner_ip \t 开服时间 \t 本地和数据中心的不匹配，请认真检查"
	# fi
# }

# check_gateway(){
	# gateway_ip=$(curl -s http://opgame.uuzu.com/api/newserver/listbyserver?server_id=$serverid |awk -F',' '{for(i=1;i<=NF;i++) print $i}'|grep "gateway_ip"|awk -F":" '{print $2}'|awk -F'"' '{print $2}')
	# /usr/bin/nmap -sS -p 8118 $gateway_ip |grep -A1 "STATE" |awk '{print $2}'|grep "open" >/dev/null 2>&1
	# if [ $? -eq 0 ];then
		# Green "OK \t $Inner_ip \t Gateway \t $gateway_ip端口8118是通的"
	# else
		# Red "Error \t $Inner_ip \t Gateway \t $gateway_ip端口8118不通，事儿大了，赶紧检查下"
	# fi
# }

check_scribe(){
	local scribe_host="$1"
	/bin/rpm -qa scribe|grep scribe>/dev/null 2>&1
	if [ $? -eq 0 ];then
		Green "OK \t $Inner_ip \t scribe \t 软件已经安装"
		scribe_file_host=$(cat /etc/scribed/default.conf |grep "remote_host" |awk -F'=' '{print $2}')
		if [ $1 == $scribe_file_host ];then
			Green "OK \t $Inner_ip \t scribe \t 远端IP \t $1"
			echo 'test' |scribe_cat -h 127.0.0.1:1464 test|tail -n 1 /var/log/scribed |grep "Successfully" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				Green "OK \t $Inner_ip \t scribe \t 工作正常"
			else
				Red "Error \t $Inner_ip \t scribe \t 工作异常，请认真检查"
			fi
		else
			Red "Error \t $Inner_ip \r scribe \t 远端IP指定有误 \t $1"
		fi
	else
		Red "Error \t $Inner_ip \t scribe \t 软件还没安装，请认真检查"
		exit
	fi
}

check_backup_file() {
	local backup_file="$1"
	local backup_name="$2"
	if [ -f $1 ];then
		Green "OK \t $Inner_ip \t $2 \t\t 备份文件存在"
	else
		Red "Error \t $Inner_ip \t $2 \t\t 备份文件不存在"
	fi
}

check_backup() {
	local backup_dir="$1"
	local backup_pro="$2"
	local date=$(date +"%H")
	local check_point=$(ls -lrt $1|tail -n 1 |awk '{print $8}'|awk -F':' '{print $1}')
	if [ -d $1 ];then
		if [ $check_point == $date ];then
			Green "OK \t $Inner_ip \t $2 \t\t 上次备份成功"
		else
			Red "Error \t $Inner_ip \t $2 \t\t 上次备份失败，请认真检查"
		fi
	else
		Red "Error \t $Inner_ip \t $1 这个目录有吗？"
		Red "Error \t $Inner_ip \t 也许是刚配服，目录还没有建立"
	fi
}

check_mysql() {
	local bakup_dir="$1"
	local date=$(date +"%d")
	local backup_all=$(ls -lrt $1 |grep -v "increase"|tail -n 1|awk '{print $7}')
	local backup_inr=$(ls -lrt $1 |grep  "increase"|tail -n 1|awk '{print $7}')
	if [ $date == $backup_all ];then
		Green "OK \t $Inner_ip \t 当日全备文件存在"
		if [ $date == $backup_inr ];then
			Green "OK \t $Inner_ip \t 当日增备文件存在"
		else
			Red "Error \t $Inner_ip \t 当日增备文件没有！"
		fi
	else
		Red "Error \t $Inner_ip \t 当日全备文件没有！"
	fi
	/data/mysql/bin/mysql  -udbmanagern -paM1c6zc2hc4VcupU  -h127.0.0.1 -e "\q"
	if [ $? -eq 0 ];then
		Green "OK \t $Inner_ip \t mysql \t\t 连接正常"
	else
		Red "Error \t $Inner_ip \t mysql \t\t 连接失败。"
	fi
}

check_ulimit(){
        if [ `sed -n '/^* *soft/p' /etc/security/limits.conf |awk '{print $NF}'|head -n1` == "65535" ];then
                Green "OK \t $Inner_ip \t 打开文件数 \t 65535"
        else
                Red "Error \t $Inner_ip \t 打开文件数小于 \t 65535"
        fi
}

check_owner(){
        if [ -d "/data/log" ];then
                if [ `find "/data/log" -user root|wc -l` -gt 0 -o `find "/data/log" -group root|wc -l` -gt 0 ];then
                        Red "Error \t $Inner_ip \t /data/log权限不完全是nobody(里边的有的文件有root权限)"
                        Green "OK \t $Inner_ip \t 改正中......"
                        /bin/chown -R nobody.nobody /data/log
                else
                        Green "OK \t $Inner_ip \t /data/log权限是nobody"
                fi
        else
                Red "Error \t $Inner_ip \t /data/log目录都没有"
        fi
}

role=$(ls /data/game/config/*.xml |tail -n 1|awk -F'/' '{print $NF}')
case $role in
	"web_log.xml")
	Green "OK \t $Inner_ip \t 此服的角色为 \t 服"
	check_nmap
	Green "OK \t $Inner_ip \t 现在开始检查\n"
	check_zabbix
	check_port web 5017
	check_port web 80
	check_mysql /data/backup/database_3308/
	check_ulimit
	;;
	"gateway.xml")
	Green "OK \t $Inner_Ip \t 此服的角色为 \t 服"
	check_nmap
	Green "OK \t $Inner_ip \t 现在开始检查\n"
	check_zabbix
	check_port gateway 9010
	check_port gateway 8118
	check_ulimit
	;;
	"scene_log.xml")
	Green "OK \t $Inner_ip \t 此服的角色为 \t 服"
	check_nmap
	Green "OK \t $Inner_ip \t 现在开始检查\n"
	check_port redis 6381
	check_port ssdb 8888
	check_port scene 9011
	check_port record_1 9020
	check_port record_2 9021
	check_port monitor 9031
	check_zabbix
	check_opentime
	check_gateway
	check_scribe 10.2.19.155
	check_backup_file /usr/local/uuzuback/redis_backup.sh redis
	check_backup_file /usr/local/uuzuback/ssdb_backup.sh ssdb
	check_backup_file /usr/local/uuzuback/uuzuback_client.py uuzu
	check_backup /data/backup/redisbase_6381/ redis
	check_backup /data/backup/ssdb_8888 ssdb
	check_ulimit
	;;
	*)
	Red "Error \t $Inner_ip \t 此服的角色为 服"
	check_ulimit
	check_owner
	;;
esac


