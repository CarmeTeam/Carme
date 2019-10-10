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
TA_PORT=$4
USER=$5
MYHASH=$6
GPUS=$7
MEM=$8

#read user accessable pert of CarmeConfig    
source /home/.CarmeScripts/CarmeConfig.container

#debug output
echo "MASTER: Theia at ${IPADDR}:${TA_PORT}"
echo "MASTER: Jupyter at ${IPADDR}:${NB_PORT}"
echo "MASTER: TensorBoard at ${IPADDR}:${TB_PORT}"
echo ""

MEM_LIMIT=$(( MEM * 1024 *1024))
echo "MASTER: Memory Limit ${MEM_LIMIT}B"
echo ""

#ulimit -d $MEM_LIMIT
#echo "MASTER: setting data seg size to" $MEM_LIMIT

export TBDIR="/home/$USER/tensorboard"
if [ ! -d $TBDIR ]; then
								  mkdir $TBDIR  										
fi                       

#Carme aliases and exporte. Get base bachrc from file
if [ ! -d ~/.carme ]; then
											mkdir ~/.carme
fi

MPI_NODES=$(cat ~/.job-log-dir/$SLURM_JOBID-nodelist)

#write carme config overwriting user settings
cat /home/.CarmeScripts/base_bashrc.sh > ~/.bashrc

echo "
#
# ~/.bash_profile
#
[[ -f ~/.bashrc ]] && . ~/.bashrc

" > ~/.bash_profile     #needed for ssh, make sure that all environment variables are sourced!

echo "
###---CARME CONFIG--###
### do not edit below - will be overritten by Carme
export TMPDIR=$HOME/carme_tmp
export TMP=$HOME/carme_tmp
export TEMP=$HOME/carme_tmp
export CARME_VERSION=$CARME_VERSION
export CARME_TMP=$HOME/carme_tmp 
export CARME_NODES=$MPI_NODES 
export CARME_MASTER=$SLURMD_NODENAME
export CARME_JOBID=$SLURM_JOBID
export CARME_JOB_NAME=$SLURM_JOB_NAME
export CARME_NUM_NODES=$SLURM_JOB_NUM_NODES
export CARME_MEM_PER_NODE=$SLURM_MEM_PER_NODE
export CARME_CPUS_PER_NODE=$SLURM_CPUS_ON_NODE 
export CARME_GPUS_PER_NODE=$CARME_SYSTEM_GPUS_PER_NODE
export CARME_GPU_LIST=$CUDA_VISIBLE_DEVICES
export CARME_ACCOUNT_CLASS=$SLURM_JOB_ACCOUNT
export CARME_QUEUE=$SLURM_JOB_PARTITION
export CARME_IMAGE=$SINGULARITY_CONTAINER
export CARME_BACKEND_SERVER=$CARME_BACKEND_SERVER
export CARME_BACKEND_PORT=$CARME_BACKEND_PORT    
export CARME_TENSORBOARD_HOME='/home/$USER/tensorboard'
alias carme_mpirun='/opt/anaconda3/bin/mpirun -host ${MPI_NODES},${MPI_NODES}, -bind-to none -map-by slot -x NCCL_DEBUG=INFO -x LD_LIBRARY_PATH -x HOROVOD_MPI_THREADS_DISABLE=1 -x PATH --mca plm rsh  --mca ras simulator --display-map --wdir ~/tmp --mca btl_openib_warn_default_gid_prefix 0 --mca orte_tmpdir_base ~/tmp --tag-output'
alias carme_cuda_version='nvcc --version'
function carme_cudnn_version () {
  CUDNN_VERSION=$(cat /opt/cuda/include/cudnn.h | grep "define CUDNN_MAJOR" | awk '{print $3}' | cut -d/ -f1)
		echo $CUDNN_VERSION
}
alias jupyter_url='echo $JUPYTER_SERVER_URL'
alias carme_ssh='ssh -p 2222'
alias nvidia-smi='nvidia-smi -i $GPUS'
" > ~/.carme/.bash_carme_$SLURM_JOBID

#sourch job bashrc to have exports in jupyterlba
source ~/.carme/.bash_carme_$SLURM_JOBID

#start multi node severs
if [ "${#GPUS}" -gt "1" ]; then #hack - needs claen solution then
#	echo "Starting DASK"
#	export LC_ALL=C.UTF-8
#	export LANG=C.UTF-8
#	DASK_JOB_DIRECTORY="/home/"$USER"/.job-log-dir/dask_job_"$SLURM_JOB_ID"_"$SLURM_JOB_NAME
#	DASK_MASTER=$(hostname)
#	DASK_NODES="${CARME_NODES[@]/,/ }"
#	DASK_SLAVES="${DASK_NODES[@]/$DASK_MASTER}"
#	DASK_MASTER_IP=$(hostname -i)
#	DASK_MASTER_PORT="8786"
# DASK_DASHBOARD_PORT="8787"
#	DASK_MASTER_WORKER_NAME_1="worker1_"$(hostname)
#	DASK_MASTER_WORKER_NAME_0="worker0_"$(hostname)	#NOTE - this works only if we have exclusive nodes (just like for MPI) 
#	DASK_MASTER_WORKER_LOCAL_DIR_0=$DASK_JOB_DIRECTORY"/"$DASK_MASTER_WORKER_NAME_0
# DASK_MASTER_WORKER_LOCAL_DIR_1=$DASK_JOB_DIRECTORY"/"$DASK_MASTER_WORKER_NAME_1
#	DASK_MASTER_WORKER_OUTPUT_1=$DASK_JOB_DIRECTORY"/"$DASK_MASTER_WORKER_LOCAL_DIR"/"$DASK_MASTER_WORKER_NAME_1".txt"    
#	DASK_MASTER_WORKER_OUTPUT_0=$DASK_JOB_DIRECTORY"/"$DASK_MASTER_WORKER_LOCAL_DIR"/"$DASK_MASTER_WORKER_NAME_0".txt"
#	DASK_SCHEDULER_DIR=${DASK_JOB_DIRECTORY}"/scheduler"
#	DASK_SCHEDULER_OUTPUT=${DASK_JOB_DIRECTORY}"/"${DASK_SCHEDULER_DIR}"/scheduler_out.txt"	
       
#	if [ -d $DASK_JOB_DIRECTORY ];then
#  		rm -r $DASK_JOB_DIRECTORY
#  		mkdir $DASK_JOB_DIRECTORY  
#	else
#  	 mkdir $DASK_JOB_DIRECTORY
#	fi             

#	/opt/anaconda3/bin/dask-scheduler --port $DASK_MASTER_PORT --bokeh-port $DASK_DASHBOARD_PORT --bokeh-prefix=/dd_${MYHASH} --local-directory ${DASK_SCHEDULER_DIR} & #scheduler output is going to generel job_log
							
#	CUDA_VISIBLE_DEVICES=0 /opt/anaconda3/bin/dask-worker ${DASK_MASTER_IP}:${DASK_MASTER_PORT} --nthreads 1 --memory-limit 0.40 --name ${DASK_MASTER_WORKER_NAME_0} --local-directory ${DASK_MASTER_WORKER_LOCAL_DIR_0} >> $DASK_MASTER_WORKER_OUTPUT_0 &
							
#	CUDA_VISIBLE_DEVICES=1 /opt/anaconda3/bin/dask-worker ${DASK_MASTER_IP}:${DASK_MASTER_PORT} --nthreads 1 --memory-limit 0.40 --name ${DASK_MASTER_WORKER_NAME_1} --local-directory ${DASK_MASTER_WORKER_LOCAL_DIR_1} >> $DASK_MASTER_WORKER_OUTPUT_1 &

	#SSHD
	touch ~/.start_sshd
 
    SSHDIR="/home/$USER/.tmp_ssh"
    if [ ! -d $SSHDIR ]; then
        mkdir $SSHDIR
    fi
							rm -rf $SSHDIR/*
							#mkdir /var/run/sshd
							#chmod 0755 /var/run/sshd
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
							echo "PermitUserEnvironment yes" >> $SSHDIR/sshd_config #to get the user env
							rm ~/.ssh/known_hosts #remove to avoid errors due to changing key
							rm ~/.ssh/config #remove old config
						 echo "SendEnv LANG LC_*" > ~/.ssh/config #crate user config
							echo "HashKnownHosts yes" >> ~/.ssh/config
							echo "GSSAPIAuthentication yes" >> ~/.ssh/config
							echo "CheckHostIP no" >> ~/.ssh/config
						 echo "StrictHostKeyChecking no" >> ~/.ssh/config
							echo "" >> ~/.ssh/config

							for i in $CARME_NODES_LIST
       do
           echo "Host "$i >> ~/.ssh/config
           echo "  HostName "$i >> ~/.ssh/config
											echo "  User $USER" >> ~/.ssh/config
           echo "  Port 2222" >> ~/.ssh/config #set default port
           echo "  IdentitiesOnly yes" >> ~/.ssh/config
           echo "  IdentityFile ~/.ssh/id_rsa" >> ~/.ssh/config
											echo "" >> ~/.ssh/config
       done               
						 env > ~/.ssh/environment #make local env available	
							echo "staring SSHD on MASTER" $(hostname)
							/usr/sbin/sshd -p 2222 -D -h ~/.tmp_ssh/server_key -E ~/.SSHD_log -f $SSHDIR/sshd_config & 
fi


# start tensorboard ----------------------------------------------------------------------------------------------------------------
#echo "Starting Tesorboard " ${TENSORBOARD_LOG_DIR} ${TB_PORT} ${MYHASH} 
TENSORBOARD_LOG_DIR="${TBDIR}/tensorboard_${SLURM_JOB_ID}"
mkdir $TENSORBOARD_LOG_DIR

/opt/anaconda3/bin/tensorboard --logdir=${TENSORBOARD_LOG_DIR} --port=${TB_PORT} --path_prefix="/tb_${MYHASH}" & 
#-----------------------------------------------------------------------------------------------------------------------------------


# start theia ----------------------------------------------------------------------------------------------------------------------
THEIA_BASE_DIR="/opt/theia-ide/"
if [ -d ${THEIA_BASE_DIR} ]; then
  #echo "Starting Theia on" $TA_PORT
  THEIA_JOB_TMP=${HOME}"/carme_tmp/"${SLURM_JOBID}"_job_tmp"
  mkdir -p $THEIA_JOB_TMP
  cd ${THEIA_BASE_DIR}
  PATH=/opt/anaconda3/bin/:$PATH TMPDIR=$THEIA_JOB_TMP TMP=$THEIA_JOB_TMP TEMP=$THEIA_JOB_TMP /opt/anaconda3/bin/node node_modules/.bin/theia start /home/${USER} --hostname $IPADDR --port $TA_PORT --startup-timeout -1 &
  cd
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# start jupyter-lab ----------------------------------------------------------------------------------------------------------------
#echo "Starting Jupyter on" $NB_PORT ${MYHASH} 
/opt/anaconda3/bin/jupyter lab --ip=$IPADDR --port=$NB_PORT --notebook-dir=/home --no-browser --config=/home/${USER}/.job-log-dir/${SLURM_JOBID}-jupyter_notebook_config.py 
#-----------------------------------------------------------------------------------------------------------------------------------

