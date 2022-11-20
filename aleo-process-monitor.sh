#!/bin/bash

log(){
	echo [`date '+%Y-%m-%d %H:%M:%S'`] $*
}

proc_name="snarkos"

# 检查启动时间，启动时间过短则退出
function check_process_runtime(){
	pid=`ps -ef|grep "$proc_name" |grep -v grep  |awk '{print $2}'`
	sys_uptime=$(cat /proc/uptime | cut -d" " -f1)
	user_hz=$(getconf CLK_TCK)

  	if [[ ! -z $pid && -f /proc/$pid/stat ]]; then 
		up_time=$(cat /proc/$pid/stat | cut -d" " -f22)
    	run_time=$((${sys_uptime%.*}-$up_time/$user_hz))
    	if [ $run_time -lt 600 ]; then 
    		log "进程执行时间 $run_time 秒，时间过短，本次不在重试，退出!!!"
    		exit(0)
    	fi 
    fi 

}

function run_aleo_prover(){
	# 执行时长检查
	check_process_runtime
	# 暴力kill 
	ps -ef|grep "$proc_name" |grep -v grep  |awk '{print $2}' |xargs kill -9
	# 加载环境变量重启 
	source $HOME/.cargo/env
	source /etc/profile
	cd /root/snarkOS
	nohup /root/snarkOS/run-prover.sh > run-prover.log 2>&1 &
	log "aleo_prover启动成功"
}

# cpu 负载判断
function check_cpu_load_rate(){
	cpu_load=`ps -aux |grep "$proc_name" |grep prover |grep -v grep |awk '{print $3}'`
	if [ $(echo "$cpu_load < 600" | bc) = 1 ]; then 
  	# cpu 负载小于期望值 重启 ，正常16core 负载在700~800之间
   	# 建议crontab 10min以上，默认由系统自动重启
    log "cpu 负载$cpu_load ,触发重启操作"
 	run_aleo_prover
 fi
}

# 周期判断
function check_cycle_unit(){
	hour=`date +"%H"`
	if [ "$(($hour % $1))" = "0" ]; then
		# 取模为0，每8小时重启
		log "判断重启周期，当前每 $1 小时重启一次，重启！！！"
		run_aleo_prover
	fi
}

# 检查进程
function check_thread_exits(){
	nums=`ps -ef|grep "$proc_name" |grep -v grep `
	if [ $nums != 1 ];then
		echo "进程数量$nums 不符合预期，重启！！！"
		run_aleo_prover
	fi
}


main(){
	check_cycle_unit 8
	check_thread_exits
	check_cpu_load_rate

}