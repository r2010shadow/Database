#!/usr/bin/env python
#coding=utf-8

'''
'''

import os,sys,json,requests


zabbix_url = 'http://zabbixapp2.uuzu.com/api_jsonrpc.php'
headers = {'content-type': 'application/json'}
user = 'admin'
password = 'L6T9duILtd41UzrN'




def printred(red):
        print '\033[31m%s\033[0m'%(red)

def printgreen(green):
        print '\033[32m%s\033[0m'%(green)

def printyellow(yellow):
        print "\033[33m%s\033[0m" %(yellow)
def help():
	print '''\033[33mUsage: %s\t[file_name]

[file_name]文件格式
IP
IP
IP
IP
IP
\033[0m''' %(sys.argv[0])

	

###登陆zabbix
def zabbix_login(user,passwd):
	data = json.dumps({						#发送的信息
		"jsonrpc": "2.0",					#json版本
		"method": "user.login",					#zabbix操作类型，这里为登陆
		"params": {						#zabbix操作动作
			"user": user,						#zabbix用户名
			"password": passwd					#zabbix密码
			},							
		"id": 1							#绑定请求或者响应,发送多个请求时有用
		})
	Requests_post = requests.post(zabbix_url,data=data,headers=headers)
	return json.loads(Requests_post.text)['result']
		
####获取zabbix主机群组列表
def zabbix_get_groups(SessionID):
	data = json.dumps({
	"jsonrpc": "2.0",
	"method": "hostgroup.get",
	"params":{
        	"output":["groupid","name"]
    	},
	"auth" : SessionID,
	"id" : 1
	})
	Requests_post = requests.post(zabbix_url,data=data,headers=headers)
	global Group_list
	Group_list = json.loads(Requests_post.text)['result']

###获取zabbix主机列表
def zabbix_get_hosts(SessionID,groupids):
        data = json.dumps({
        "jsonrpc": "2.0",
        "method": "host.get",
        "params":{
        "output":["hostid","name"],
		"groupids":groupids,
        	},
        "auth" : SessionID,
        "id" : 1
        })
        Requests_post = requests.post(zabbix_url,data=data,headers=headers)
	global host_list
	host_list = json.loads(Requests_post.text)['result']
###zabbix模版获取
def zabbix_get_template(SessionID,groupids):
        data = json.dumps({
        "jsonrpc": "2.0",
        "method": "template.get",
        "params":{
        	"output":["templateid","name"],
		"groupids":groupids
                },
        "auth" : SessionID,
        "id" : 1
        })
        Requests_post = requests.post(zabbix_url,data=data,headers=headers)
	global template_list
        template_list = json.loads(Requests_post.text)['result']

###zabbix###proxy获取
def zabbix_get_proxy(SessionID):
	data = json.dumps({
	"jsonrpc": "2.0",
        "method": "proxy.get",
        "params":{
                "output":["proxyid","host"],
                },
        "auth" : SessionID,
        "id" : 1
	})
	Requests_post = requests.post(zabbix_url,data=data,headers=headers)
	global proxy_list
	proxy_list = json.loads(Requests_post.text)['result']
	
	

###添加主机到zabbix
def zabbix_create_host(SessionID,hostip,groupid,templateid,proxyid):
        data = json.dumps({
        "jsonrpc": "2.0",
        "method": "host.create",
        "params":{
		"host":hostip,
		"proxy_hostid":proxyid,
		"interfaces":[{
			"type": 1,
                	"main": 1,
                	"useip": 1,
                	"ip":hostip,
                	"dns": "",
                	"port": "10050"
		}],
        	"groups":[{
			"groupid":groupid
		}],
		"templates":[{
			"templateid":templateid
		}],
	},
        "auth" : SessionID,
        "id" : 1
        })
        Requests_post = requests.post(zabbix_url,data=data,headers=headers)

###删除主机群组
def zabbix_delete_host(SessionID,hostid_list):
        data = json.dumps({
        "jsonrpc": "2.0",
        "method": "host.delete",
        "params":hostid_list,
        "auth" : SessionID,
        "id" : 1
        })
        Requests_post = requests.post(zabbix_url,data=data,headers=headers)
	return Requests_post

#############################	


#获取登录zabbix的SessionID
#SessionID = zabbix_login('admin','zabbix')
SessionID = zabbix_login(user,password)

#循环操作选项
while True:
	printyellow('''==========================
        1.添加主机
        2.删除主机
        3.查询主机群组
        4.模版查询
	5.proxy查询
	6.退出
==========================''')
	try:
		user_input_value = int(raw_input('\033[32m按照提示输入序列号:\033[0m'))
	except	ValueError:
		printred('输入错误,重新输入!')
		continue
	if user_input_value < 1 or user_input_value > 6:
		printred('输入错误,重新输入!')
		continue
	elif user_input_value == 6:
		sys.exit()
	#添加主机到zabbix
	if user_input_value == 1:
		if len(sys.argv) != 2:
			help()
			sys.exit()
		#关联主机群组
		zabbix_get_groups(SessionID)
		group_WordBook = {}
		for group in sorted(Group_list):
			key = group['name'].encode('utf-8')
			value = group['groupid']
			group_WordBook[key] = value
                	print '\033[33m主机群组名:\t%s\033[0m' % group['name'].encode('utf-8')
		user_input_Group = raw_input('\033[32m选择添加到的主机群组名:\033[0m').strip()
		#关联模版
		groupids = group_WordBook[user_input_Group]
		zabbix_get_template(SessionID,groupids)
		template_WordBook = {}
		for template in sorted(template_list):
			key = template['name'].encode('utf-8')
			value = template['templateid']
			template_WordBook[key] = value		
                        print '\033[33m模版名字:\t%s\033[0m' % template['name'].encode('utf-8')
		user_input_template = raw_input('\033[32m选择需要关联到的莫板名:\033[0m').strip()
		#关联proxy代理
		while True:
			user_inpput_yesno = raw_input('\033[32m该主机是否关联proxy代理:[y/n]\033[0m').strip()
			if user_inpput_yesno == 'n':
				proxyid = '0'
				break
			elif user_inpput_yesno == 'y':
				zabbix_get_proxy(SessionID)
				proxy_WordBook = {}
                		for proxy in proxy_list:
                        		key = str(proxy['host'])
                        		value = proxy['proxyid']
                        		proxy_WordBook[key] = value
                        		printyellow('proxy名字:\t%s' %(proxy['host'].encode('utf-8')))
				while True:
					user_input_proxy = raw_input('\033[32m输入需要代理的proxy名字:\033[0m').strip()
					if user_input_proxy in proxy_WordBook:
						proxyid = proxy_WordBook[user_input_proxy]
						break
					else:
						printred('输入proxy名不存在,重新输入!')
						continue
				break
			else:
				printred('输入错误,重新输入!')
				continue
		File_name = sys.argv[1]
		F = open(File_name)
		C = F.readlines()
		F.close()
		Numb = len(C)
		user_input = raw_input('\033[32m%s个主机将添加到zabbix,确认[y],退出:[任意字符]\033[0m' %(Numb)).strip()
		if user_input != 'y':
			printred("退出")
			sys.exit()
		for line in C:
			F_line = line.split()
			hostip = F_line[0]
			groupid = group_WordBook[user_input_Group]
			templateid = template_WordBook[user_input_template]
			try:
				zabbix_create_host(SessionID,hostip,groupid,templateid,proxyid)
			except:
				printred('%s\t添加到zabbix失败' %(hostip))
			else:
				printgreen('%s\t添加到主机群组%s成功\t关联到模版%s成功' %(hostip,user_input_Group,user_input_template))
		
		
	#删除主机
	if user_input_value == 2:
		if len(sys.argv) != 2:
			help()
			sys.exit()
		zabbix_get_groups(SessionID)
		group_WordBook = {}
		for group in sorted(Group_list):
                        key = group['name'].encode('utf-8')
                        value = group['groupid']
                        group_WordBook[key] = value
                        print '\033[33m主机群组名:\t%s\033[0m' % group['name'].encode('utf-8')
                user_input_Group = raw_input('\033[32m选择要删除的主机群组名:\033[0m').strip()
		groupids = group_WordBook[user_input_Group]
		zabbix_get_hosts(SessionID,groupids)
		host_WordBook = {}
		for host in host_list:
			key =  host['name']
			value = host['hostid']
			host_WordBook[key] = value
		file_name = sys.argv[1]
		F = open(file_name)
		C = F.readlines()
		F.close()
		for ip in C:
			hostid_list = []
			ip = str(ip.strip('\n').strip())
			if ip in host_WordBook:
				pass
			else:
				printred('%s\t\t不在zabbix中' %(ip))
				continue
			hostid = host_WordBook[ip]
			hostid_list.append(hostid)
			if len(hostid_list) == 0:
				printred('没有可以删除的IP,退出!')
				sys.exit()
			try:
				zabbix_delete_host(SessionID,hostid_list)
			except:
				printred('%s\t\t删除失败!' %(ip))
			else:
				printgreen('%s\t\t删除成功!' %(ip))
			
		
	
	#查询某个主机群组的主机列表
	if user_input_value == 3:
		zabbix_get_groups(SessionID)
		group_WordBook = {}
		for group in Group_list:
			key = group['name'].encode('utf-8')
                        value = group['groupid']
                        group_WordBook[key] = value
			print '\033[33m主机群组名:\t%s\033[0m' % group['name'].encode('utf-8')
		user_input_group = raw_input('\033[32m输入查询主机群组名:\033[0m')
		groupids = group_WordBook[user_input_group]
		zabbix_get_hosts(SessionID,groupids)
		for host in host_list:
			print '\033[33m主机名:\t%s\033[0m' % host['name'].encode('utf-8')
	#查询所有模版
	if user_input_value == 4:
		zabbix_get_groups(SessionID)
                group_WordBook = {}
                for group in Group_list:
                        key = group['name'].encode('utf-8')
                        value = group['groupid']
                        group_WordBook[key] = value
                        print '\033[33m主机群组名:\t%s\033[0m' % group['name'].encode('utf-8')
                user_input_group = raw_input('\033[32m输入查询主机群组名:\033[0m')
                groupids = group_WordBook[user_input_group]
		zabbix_get_template(SessionID,groupids)
                template_WordBook = {}
                for template in sorted(template_list):
                        key = template['name']
                        value = template['templateid']
                        template_WordBook[key] = value
                        print '\033[33m模版名字:\t%s\033[0m' % template['name'].encode('utf-8')		
	#proxy获取
	if user_input_value == 5:
		zabbix_get_proxy(SessionID)
		proxy_WordBook = {}	
		for proxy in proxy_list:
			key = proxy['host']
			value = proxy['proxyid']
			proxy_WordBook[key] = value
			printyellow('proxy名字:\t%s' %(proxy['host'].encode('utf-8')))
		

