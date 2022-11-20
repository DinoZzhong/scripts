#!/bin/bash
# ================
#  A 下载命令：cd ~ && wget -O /root/aleo-process-monitor.sh https://raw.githubusercontent.com/DinoZzhong/scripts/main/aleo-process-monitor.sh
#  B 执行命令 bash {脚本文件名}
#  C crontab 部署步骤
#   1、执行： crontab -e 
#   2、写入: */1 * * * * bash /root/aleo-process-monitor.sh >/root/monitor.log >&1 &
#   3、按esc ，再 :wq 三个字符，自后回车退出
#   4、检查： 执行crontab -l 如果出现步骤2中命令单独一行即为成功
#   5、后续观察，可查看/root/monitor.log 日志文件观察守护记录

# ===============
log(){
  echo [`date '+%Y-%m-%d %H:%M:%S'`] $*
}
log "开始检查"

proc_name="snarkos"

# 检查启动时间，启动时间过短则退出
function check_process_runtime(){
  log "进入启动prover检查..."
  pid=`ps -ef|grep "$proc_name" |grep -v grep  |awk '{print $2}'`
  sys_uptime=$(cat /proc/uptime | cut -d" " -f1)
  user_hz=$(getconf CLK_TCK)

    if [[ ! -z $pid && -f /proc/$pid/stat ]]; then 
      up_time=$(cat /proc/$pid/stat | cut -d" " -f22)
      run_time=$((${sys_uptime%.*}-$up_time/$user_hz))
      if [ $run_time -lt 300 ]; then 
        log "进程执行时间 $run_time 秒，时间过短，本次不在重试，退出!!!"
        exit 0
      else
        log "进程已执行 $run_time 秒"
      fi 
    else 
      log "进程信息未获取到.跳过启动时间检查"
    fi 

}

function run_aleo_prover(){
  
  # 执行时长检查
  check_process_runtime
  log "开始启动执行"
  ## 暴力kill 
  ps -ef|grep "$proc_name" |grep -v grep  |awk '{print $2}' |xargs -r kill -9
  ## 加载环境变量重启 ß
  # source /root/.cargo/env
  # source /etc/profile
  #nohup /root/snarkOS/run-prover.sh > /root/snarkOS/run-prover.log 2>&1 &
  
  echo 3 | bash aleo3-daniel.sh
  log "aleo_prover启动成功,执行中，可查看/root/snarkOS/run-prover.log 确认状态"
  # 执行完成就退出
  exit 0

}

# cpu 负载判断
function check_cpu_load_rate(){
  cpu_load=`ps -aux |grep "$proc_name" |grep -v grep |awk '{print $3}'`
  if [[ ! -z $cpu_load && $(echo "$cpu_load < 600" | bc ) = 1 ]]; then 
    # cpu 负载小于期望值 重启 ，正常16core 负载在700~800之间
    # 建议crontab 10min以上，默认由系统自动重启
    log "cpu 负载$cpu_load ,触发重启操作"
    run_aleo_prover
  fi
  log "cpu 负载 $cpu_load 在预期内"
}

# 周期判断，定时重启
function check_cycle_unit(){
  hour=`date +"%H"`
  if [ "$(($hour % $1))" = "0" ]; then
    # 取模为0，每8小时重启
    log "判断重启周期，当前每 $1 小时重启一次，重启！！！"
    run_aleo_prover
  fi
  log "不符合周期重启逻辑，跳过"
}

# 检查进程
function check_thread_exits(){
  nums=`ps -ef|grep "$proc_name" |grep -v grep |wc -l `
  if [ $nums != 1 ];then
    log "进程数量$nums 不符合预期，重启！！！"
    run_aleo_prover
  fi
  log "进程数量符合预期，跳过"
}

main(){
  check_thread_exits
  check_cycle_unit 8
  check_cpu_load_rate
  log "检查完成,本次正常.."
}

main 
