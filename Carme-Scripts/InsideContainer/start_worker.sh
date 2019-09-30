#!/bin/bash

#--------------------------------------------
# Default container startup script
#
# * starts jupyter end tensorboard
# * set env
# 
#--------------------------------------------

IPADDR=$1
NB_PORT=$2
TB_PORT=$3
USER=$4
HASH=$5
GPUS=$6
MEM=$7

#read user accessable pert of CarmeConfig 
source /home/.CarmeScripts/CarmeConfig.container  

#debug output
MEM_LIMIT=$(( MEM * 1024 *1024 ))
echo "WORKER: Memory Limit ${MEM_LIMIT}B"
echo ""

#ulimit -d $MEM_LIMIT
#echo "WORKER: setting data seg size to" $MEM_LIMIT

export TMPDIR=$HOME/carme_tmp
export TMP=$HOME/carme_tmp
export TEMP=$HOME/carme_tmp

SSHDIR="/home/$USER/.tmp_ssh"

#sleep for while, so the master can setup ssh
sleep 10
source ~/.carme/.bash_carme_$SLURM_JOBID 

#start DASK worker
#export LC_ALL=C.UTF-8
#export LANG=C.UTF-8
#DASK_JOB_DIRECTORY="/home/"$USER"/.job-log-dir/dask_job_"$SLURM_JOB_ID"_"$SLURM_JOB_NAME
#DASK_MASTER=${CARME_MASTER}

#echo "DASK MASTER: " $DASK_MASTER
#DASK_NODES=("${CARME_NODES[@]/,/ }")
#DASK_SLAVES=("${DASK_NODES[@]/$DASK_MASTER}")
#DASK_MASTER_IP=$(getent hosts $DASK_MASTER | awk '{ print $1 }')
#echo "DASK_MASTER_IP " $DASK_MASTER_IP 
#DASK_MASTER_PORT="8786"
#DASK_WORKER_NAME_1="worker1_"$(hostname)
#DASK_WORKER_NAME_0="worker0_"$(hostname)
#DASK_WORKER_LOCAL_DIR_0=$DASK_JOB_DIRECTORY"/"$DASK_WORKER_NAME_0
#DASK_WORKER_LOCAL_DIR_1=$DASK_JOB_DIRECTORY"/"$DASK_WORKER_NAME_1
#DASK_WORKER_OUTPUT_1=$DASK_JOB_DIRECTORY"/"$DASK_WORKER_LOCAL_DIR"/"$DASK_WORKER_NAME_1".txt"
#DASK_WORKER_OUTPUT_0=$DASK_JOB_DIRECTORY"/"$DASK_WORKER_LOCAL_DIR"/"$DASK_WORKER_NAME_0".txt"

#CUDA_VISIBLE_DEVICES=0 /opt/anaconda3/bin/dask-worker ${DASK_MASTER_IP}:${DASK_MASTER_PORT} --nthreads 1 --memory-limit 0.40 --name ${DASK_WORKER_NAME_0} --local-directory ${DASK_WORKER_LOCAL_DIR_0} >> $DASK_WORKER_OUTPUT_0 &

#CUDA_VISIBLE_DEVICES=1 /opt/anaconda3/bin/dask-worker ${DASK_MASTER_IP}:${DASK_MASTER_PORT} --nthreads 1 --memory-limit 0.40 --name ${DASK_WORKER_NAME_1} --local-directory ${DASK_WORKER_LOCAL_DIR_1} >> $DASK_WORKER_OUTPUT_1 &


#start SSH server
if [ "$SLURM_JOB_NUM_NODES" != 1 ]; then  
       /usr/sbin/sshd -p 2222 -D -h ~/.tmp_ssh/server_key -E ~/.SSHD_log -f $SSHDIR/sshd_config
							echo "WORKER: SSH deamon started on $(hostname)"
fi
