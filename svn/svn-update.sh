#/bin/bash
#SVN.rsync-update-files
Red() {
	echo -ne "\033[31m"$1"\033[0m\n"
}
Green(){
	echo -ne "\033[32m"$1"\033[0m\n"
}


#选择混服或者AppStore
echo
Red "\t记得编辑conf/下的IP列表文件"
echo
platforms="app andriod"
Green "
请选择要更新的:\n\n
"
select platform in $platforms ;do
        if [ $platform ];then
                Green "更新的类型为: $platform"
                break
        else
                Red "Again Choice."
        fi
done

#更新SVN
rsyncdir=$(grep $platform ./config.conf -B1 -A3|grep "rsyncdir"|awk -F"=" '{print $2}')
rsyncmod=$(grep $platform ./config.conf -B1 -A3|grep "rsyncmod" |awk -F"=" '{print $2}')
hostfile=$(grep $platform ./config.conf -B1 -A3|grep "listfile" |awk -F"=" '{print $2}')
svn up $rsyncdir >/dev/null 2>&1
if [ $? -ne 0 ];then
	Red "Error\t\t$platform 更新失败了,fuck......"
else
	Green "OK\t\t$platform  更新成功了,genius......"
fi

#上传文件
current_revision=$(cd ${rsyncdir} ; svn info | grep "Last Changed Rev" | awk '{print $4}')
read -p "输入版本号: " revision_input
if [ "${revision_input}" != "${current_revision}" ];then
        Red "版本号错误,当前版本号为: ${current_revision}."
        exit
fi

update_time=$(date +"%Y-%m-%d-%H-%M-%S")
logdir="`pwd`/log/$update_time"
mkdir -p $logdir
threadnum="50"
tmpfifo="${logdir}/$$.fifo"
mkfifo $tmpfifo

exec 6<>$tmpfifo
for ((i=0;i<$threadnum;i++));do
        echo 1   >&6
done

cd $rsyncdir
Green "OK\t\t准备上传了......\n"
for host in `cat $hostfile`;do
	{
	read -u6
	/usr/local/rsync308/bin/rsync -lrRptWv --delete --contimeout=30 --port 873 --exclude-from=/etc/rsync_exclude.conf * $host::$rsyncmod >> $logdir/$host && Green "OK\t\t$host\t\tupdate sucessful"|tee -a $logdir/$host || Red "Error\t\t$host\t\tupdate failed,fuck......"|tee -a $loggdir/$host;echo 1>&6
	} &
done
wait
exec 6>&-
rm -f $tmpfifo
