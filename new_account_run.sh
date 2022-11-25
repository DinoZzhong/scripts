#!/bin/bash

log(){
  echo [`date '+%Y-%m-%d %H:%M:%S'`] $*
}
log "start new account..."
cd ~ 
source /root/.cargo/env
snarkos account new > /root/aleo.txt
sed -i '/PROVER_PRIVATE_KEY/,1d' /etc/profile
PrivateKey=$(cat /root/aleo.txt | grep Private | awk '{print $3}')
log newkey: $PrivateKey

echo  export PROVER_PRIVATE_KEY=$PrivateKey >> /etc/profile

source /etc/profile
cat /etc/profile |grep PROVER_PRIVATE_KEY

log "kill restart..."
ps -ef|grep snark |grep -v grep  |awk '{print $2}' |xargs -r kill -9

echo 3|bash aleo3-daniel.sh 
sleep 3 
echo 3|bash aleo3-daniel.sh 
log "===address detail====="
cat aleo.txt
cat aleo.txt >> ~/address_list.txt