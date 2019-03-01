#!/bin/bash

#--------------------------------------------
# run automated test to check the carme environment
# 
#--------------------------------------------

IPADDR=$1
NB_PORT=$2
TB_PORT=$3
USER=$4
HASH=$5
GPUS=$6
MEM=$7

#debug output
echo "running on" $IPADDR
echo "Jupyter Port" $NB_PORT
echo "TB Port" $TB_PORT
echo "GPUs " $GPUS
MEM_LIMIT=$(( MEM * 1000000 ))
echo "starting with mem limit" $MEM_LIMIT

ulimit -v $MEM_LIMIT

export CUDA_VISIBLE_DEVICES=$GPUS
TBDIR="/home/$USER/tensorboard"
if [ ! -d $TBDIR ]; then
  mkdir $TBDIR
fi

#start SSH server
if [ "$SLURM_JOB_NUM_NODES" != 1 ]; then
							touch ~/.start_sshd
 
       SSHDIR="/home/$USER/.tmp_ssh"
       if [ ! -d $SSHDIR ]; then
         		mkdir $SSHDIR
       fi
							rm -rf $SSHDIR/*
							mkdir /var/run/sshd
							chmod 0755 /var/run/sshd
							ssh-keygen -t ssh-rsa -N "" -f $SSHDIR/server_key
				   ssh-keygen -t rsa -N "" -f $SSHDIR/client_key
				   rm ~/.ssh/authorized_keys
							rm ~/.ssh/id_rsa
							cat $SSHDIR/client_key.pub > ~/.ssh/authorized_keys	
					  cat $SSHDIR/client_key > ~/.ssh/id_rsa
						 chmod 700 ~/.ssh/id_rsa		
							echo "PermitRootLogin yes" > $SSHDIR/sshd_config
							echo "PubkeyAuthentication yes" >> $SSHDIR/sshd_config 
							echo "ChallengeResponseAuthentication no" >> $SSHDIR/sshd_config 
							echo "UsePAM no" >> $SSHDIR/sshd_config 
							echo "X11Forwarding no" >> $SSHDIR/sshd_config 
							echo "PrintMotd no" >> $SSHDIR/sshd_config 
							echo "AcceptEnv LANG LC_*" >> $SSHDIR/sshd_config 
							echo "AllowUsers" $USER >> $SSHDIR/sshd_config #only allow connections by user
							rm ~/.ssh/known_hosts #remove to avoid errors due to changing key
							rm ~/.ssh/config #remove old config
						 echo "SendEnv LANG LC_*" > ~/.ssh/config #crate user config
							echo "HashKnownHosts yes" >> ~/.ssh/config
							echo "GSSAPIAuthentication yes" >> ~/.ssh/config
							echo "CheckHostIP no" >> ~/.ssh/config
						 echo "StrictHostKeyChecking no" >> ~/.ssh/config
						 echo "Host dev" >> ~/.ssh/config
					  echo "			Port 2222" >> ~/.ssh/config #set default port 		
							/usr/sbin/sshd -p 2222 -D -h ~/.tmp_ssh/server_key -E ~/.SSHD_log -f $SSHDIR/sshd_config & 
fi

#test by test
export SYSTEST_OUT=~/.carme/systest.txt
echo "CARME SYSTEM TEST \n\n" > $SYSTEST_OUT
carme_mpirun -n 4 /home/.CarmeScripts/test/mpi/pi_test >> $SYSTEST_OUT

echo "\n\n ## Jupyter ##" >> $SYSTEST_OUT 
/opt/anaconda3/bin/jupyter lab --ip=$IPADDR --port=$NB_PORT --notebook-dir=/home --no-browser >> $SYSTEST_OUT  &
echo "\n\n ## TB ##" >> $SYSTEST_OUT
/opt/anaconda3/bin/tensorboard tensorboard --logdir="/home/$USER/tensorboard" --port=${TB_PORT} --path_prefix="/tb_${HASH}" >> $SYSTEST_OUT &

echo "\n\n all tests done" >> $SYSTEST_OUT 
