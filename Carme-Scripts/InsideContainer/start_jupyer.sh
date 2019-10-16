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
alias carme_mpirun='/opt/anaconda3/bin/mpirun -bind-to none -map-by slot -x NCCL_DEBUG=INFO -x LD_LIBRARY_PATH -x HOROVOD_MPI_THREADS_DISABLE=1 -x PATH --mca plm rsh  --mca ras simulator --display-map --wdir ~/tmp --mca btl_openib_warn_default_gid_prefix 0 --mca orte_tmpdir_base ~/tmp --tag-output'
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

#start additional stuff if we have more than one node or more than one GPU
if [[ "$SLURM_JOB_NUM_NODES" -gt "1" || "${#GPUS}" -gt "1" ]]; then
	 # start SSHD
	 touch ~/.start_sshd
  SSHDIR="/home/$USER/.tmp_ssh"
  mkdir -p $SSHDIR
		ssh-keygen -t ssh-rsa -N "" -f $SSHDIR/server_key_${SLURM_JOB_ID}
		ssh-keygen -t rsa -N "" -f $SSHDIR/client_key_${SLURM_JOB_ID}
		#rm ~/.ssh/authorized_keys
		#rm ~/.ssh/id_rsa
		cat $SSHDIR/client_key_${SLURM_JOB_ID}.pub > ~/.ssh/authorized_keys
		cat $SSHDIR/client_key_${SLURM_JOB_ID} > ~/.ssh/id_rsa_${SLURM_JOB_ID}
		chmod 700 ~/.ssh/id_rsa_${SLURM_JOB_ID}
		echo "PermitRootLogin yes" > $SSHDIR/sshd_config_${SLURM_JOB_ID}
		echo "PubkeyAuthentication yes" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		echo "ChallengeResponseAuthentication no" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		echo "UsePAM no" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		echo "X11Forwarding no" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		echo "PrintMotd no" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		echo "AcceptEnv LANG LC_*" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		echo "AllowUsers" $USER >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		#echo "PermitUserEnvironment yes" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		rm ~/.ssh/known_hosts
		rm ~/.ssh/config
		echo "SendEnv LANG LC_*" > ~/.ssh/config
		echo "HashKnownHosts yes" >> ~/.ssh/config
		echo "GSSAPIAuthentication yes" >> ~/.ssh/config
		echo "CheckHostIP no" >> ~/.ssh/config
		echo "StrictHostKeyChecking no" >> ~/.ssh/config
		echo "" >> ~/.ssh/config

		for i in $CARME_NODES_LIST;do
    echo "Host "$i >> ~/.ssh/config
    echo "  HostName "$i >> ~/.ssh/config
				echo "  User $USER" >> ~/.ssh/config
    echo "  Port 2222" >> ~/.ssh/config
    echo "  IdentitiesOnly yes" >> ~/.ssh/config
    echo "  IdentityFile ~/.ssh/id_rsa" >> ~/.ssh/config
				echo "" >> ~/.ssh/config
  done               
		#env > ~/.ssh/environment
		echo "staring SSHD on MASTER" $(hostname)
		/usr/sbin/sshd -p 2222 -D -h ~/.tmp_ssh/server_key_${SLURM_JOB_ID} -E ~/.SSHD_log_${SLURM_JOB_ID} -f $SSHDIR/sshd_config_${SLURM_JOB_ID} &

		echo "alias ssh='ssh -i /home/${USER}/.ssh/id_rsa_${SLURM_JOB_ID}'" >> ~/.carme/.bash_carme_${SLURM_JOBID}
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

