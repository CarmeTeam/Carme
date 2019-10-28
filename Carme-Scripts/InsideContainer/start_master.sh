#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Default container startup script
#
# * starts jupyter end tensorboard
# * set env
# 
#-----------------------------------------------------------------------------------------------------------------------------------

IPADDR=$1
NB_PORT=$2
TB_PORT=$3
TA_PORT=$4
USER=$5
MYHASH=$6
GPUS=$7
MEM=$8

#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from /home/.CarmeScripts/CarmeConfig.container
CONFIG_FILE="/home/.CarmeScripts/CarmeConfig.container"
if [ -f ${CONFIG_FILE} ];then
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=${variable_value%#*}
    variable_value=${variable_value%#*}
    variable_value=$(echo "$variable_value" | tr -d '"')
    echo $variable_value
  }
else
  echo "${CONFIG_FILE} not found!"
  exit 137
fi

CARME_VERSION=$(get_variable CARME_VERSION ${CONFIG_FILE})
CARME_SYSTEM_GPUS_PER_NODE=$(get_variable CARME_SYSTEM_GPUS_PER_NODE ${CONFIG_FILE})
CARME_BACKEND_SERVER=$(get_variable CARME_BACKEND_SERVER ${CONFIG_FILE})
CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${CONFIG_FILE})
CARME_NODES_LIST=$(get_variable CARME_NODES_LIST ${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

echo "MASTER: Theia at ${IPADDR}:${TA_PORT}"
echo "MASTER: Jupyter at ${IPADDR}:${NB_PORT}"
echo "MASTER: TensorBoard at ${IPADDR}:${TB_PORT}"
echo ""

MEM_LIMIT=$(( MEM * 1024 *1024))
echo "MASTER: Memory Limit ${MEM_LIMIT}KB"
echo ""


# Carme specific/needed aliases and exports ----------------------------------------------------------------------------------------
export TBDIR="${HOME}/tensorboard"
mkdir -p $TBDIR

mkdir -p ${HOME}/.carme

MPI_NODES=$(cat ~/.job-log-dir/$SLURM_JOB_ID-nodelist)

# write carme config overwriting user settings
cat /home/.CarmeScripts/base_bashrc.sh > ~/.bashrc

echo "
#
# ${HOME}/.bash_profile
#
[[ -f ${HOME}/.bashrc ]] && . ~/.bashrc

" > ${HOME}/.bash_profile

echo "
###---CARME CONFIG--###
### do not edit below - will be overritten by Carme
export TMPDIR=${HOME}/carme_tmp
export TMP=${HOME}/carme_tmp
export TEMP=${HOME}/carme_tmp
export CARME_VERSION=${CARME_VERSION}
export CARME_TMP=${HOME}/carme_tmp
export CARME_NODES=${MPI_NODES}
export CARME_MASTER=${SLURMD_NODENAME}
export CARME_JOBID=${SLURM_JOB_ID}
export CARME_JOB_NAME=${SLURM_JOB_NAME}
export CARME_NUM_NODES=${SLURM_JOB_NUM_NODES}
export CARME_MEM_PER_NODE=${SLURM_MEM_PER_NODE}
export CARME_CPUS_PER_NODE=${SLURM_CPUS_ON_NODE}
export CARME_GPUS_PER_NODE=${CARME_SYSTEM_GPUS_PER_NODE}
export CARME_GPU_LIST=${CUDA_VISIBLE_DEVICES}
export CARME_ACCOUNT_CLASS=${SLURM_JOB_ACCOUNT}
export CARME_QUEUE=${SLURM_JOB_PARTITION}
export CARME_IMAGE=${SINGULARITY_CONTAINER}
export CARME_BACKEND_SERVER=${CARME_BACKEND_SERVER}
export CARME_BACKEND_PORT=${CARME_BACKEND_PORT}    
export CARME_TENSORBOARD_HOME='${HOME}/tensorboard'
alias carme_mpirun='/opt/anaconda3/bin/mpirun -bind-to none -map-by slot -x NCCL_DEBUG=INFO -x LD_LIBRARY_PATH -x HOROVOD_MPI_THREADS_DISABLE=1 -x PATH --mca plm rsh  --mca ras simulator --display-map --wdir ~/tmp --mca btl_openib_warn_default_gid_prefix 0 --mca orte_tmpdir_base ~/tmp --tag-output'
alias carme_cuda_version='nvcc --version'
function carme_cudnn_version () {
  CUDNN_VERSION=$(cat /opt/cuda/include/cudnn.h | grep "define CUDNN_MAJOR" | awk '{print $3}' | cut -d/ -f1)
		echo ${CUDNN_VERSION}
}
alias jupyter_url='echo $JUPYTER_SERVER_URL'
alias carme_ssh='ssh -p 2222'
alias nvidia-smi='nvidia-smi -i $GPUS'
" > ${HOME}/.carme/.bash_carme_${SLURM_JOB_ID}

#source job bashrc
source ${HOME}/.carme/.bash_carme_${SLURM_JOB_ID}
#-----------------------------------------------------------------------------------------------------------------------------------


#start additional stuff if we have more than one node or more than one GPU ---------------------------------------------------------
if [[ "$SLURM_JOB_NUM_NODES" -gt "1" || "${#GPUS}" -gt "1" ]]; then
  # start SSHD
  SSHDIR="${HOME}/.carme/tmp_ssh_${SLURM_JOB_ID}"
  mkdir -p $SSHDIR
  ssh-keygen -t ssh-rsa -N "" -f $SSHDIR/server_key_${SLURM_JOB_ID}
  ssh-keygen -t rsa -N "" -f ${HOME}/.ssh/id_rsa_${SLURM_JOB_ID}
  mv ${HOME}/.ssh/id_rsa_${SLURM_JOB_ID}.pub ${SSHDIR}/id_rsa_${SLURM_JOB_ID}.pub
  cat ${SSHDIR}/id_rsa_${SLURM_JOB_ID}.pub >> ${SSHDIR}/authorized_keys_${SLURM_JOB_ID}

  echo "PermitRootLogin no" > $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "PubkeyAuthentication yes" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "ChallengeResponseAuthentication no" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "UsePAM no" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "AuthorizedKeysFile ${SSHDIR}/authorized_keys_${SLURM_JOB_ID}" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "LoginGraceTime 30s" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "MaxAuthTries 3" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "ClientAliveInterval 3600" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "ClientAliveCountMax 1" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "X11Forwarding no" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "PrintMotd no" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "AcceptEnv LANG LC_* CUDA* ENVIRONMENT GIT* GPU_DEVICE_ORDINAL HASH HOSTNAME JUPYTER_DATA LD_LIBRARY_PATH SINGULARITY* SLURM* S_COLORS TBDIR XGD_RUNTIME_DIR" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
  echo "AllowUsers" $USER >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		echo "PermitUserEnvironment no" >> $SSHDIR/sshd_config_${SLURM_JOB_ID}
		chmod 640 $SSHDIR/sshd_config_${SLURM_JOB_ID}

  rm ${HOME}/.ssh/known_hosts
  rm ${HOME}/.ssh/config
  
		echo "SendEnv LANG LC_* CUDA* ENVIRONMENT GIT* GPU_DEVICE_ORDINAL HASH HOSTNAME JUPYTER_DATA LD_LIBRARY_PATH SINGULARITY* SLURM* S_COLORS TBDIR XGD_RUNTIME_DIR" > ${HOME}/.ssh/config
  echo "HashKnownHosts yes" >> ${HOME}/.ssh/config
  echo "GSSAPIAuthentication yes" >> ${HOME}/.ssh/config
  echo "CheckHostIP no" >> ${HOME}/.ssh/config
  echo "StrictHostKeyChecking no" >> ${HOME}/.ssh/config
  echo "" >> ${HOME}/.ssh/config

  for i in $CARME_NODES_LIST;do
    echo "Host "$i >> ${HOME}/.ssh/config
    echo "  HostName "$i >> ${HOME}/.ssh/config
    echo "  User $USER" >> ${HOME}/.ssh/config
    echo "  Port 2222" >> ${HOME}/.ssh/config
    echo "  IdentitiesOnly yes" >> ${HOME}/.ssh/config
    echo "  IdentityFile ~/.ssh/id_rsa" >> ${HOME}/.ssh/config
    echo "" >> ${HOME}/.ssh/config
  done
  chmod 640 ${HOME}/.ssh/config		
  
  echo "starting SSHD on MASTER" $(hostname)
  /usr/sbin/sshd -p 2222 -D -h ${SSHDIR}/server_key_${SLURM_JOB_ID} -E ${SSHDIR}/sshd_log_${SLURM_JOB_ID} -f ${SSHDIR}/sshd_config_${SLURM_JOB_ID} &
  
  echo "alias ssh='ssh -i ${HOME}/.ssh/id_rsa_${SLURM_JOB_ID}'" >> ${HOME}/.carme/.bash_carme_${SLURM_JOB_ID}
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# start tensorboard ----------------------------------------------------------------------------------------------------------------
TENSORBOARD_LOG_DIR="${TBDIR}/tensorboard_${SLURM_JOB_ID}"
mkdir ${TENSORBOARD_LOG_DIR}
/opt/anaconda3/bin/tensorboard --logdir=${TENSORBOARD_LOG_DIR} --port=${TB_PORT} --path_prefix="/tb_${MYHASH}" & 
#-----------------------------------------------------------------------------------------------------------------------------------


# start theia ----------------------------------------------------------------------------------------------------------------------
THEIA_BASE_DIR="/opt/theia-ide/"
if [ -d ${THEIA_BASE_DIR} ]; then
  THEIA_JOB_TMP=${HOME}"/carme_tmp/"${SLURM_JOB_ID}"_job_tmp"
  mkdir -p ${THEIA_JOB_TMP}
  cd ${THEIA_BASE_DIR}
  PATH=/opt/anaconda3/bin/:${PATH} TMPDIR=${THEIA_JOB_TMP} TMP=${THEIA_JOB_TMP} TEMP=${THEIA_JOB_TMP} /opt/anaconda3/bin/node node_modules/.bin/theia start ${HOME} --hostname ${IPADDR} --port ${TA_PORT} --startup-timeout -1 &
  cd
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# start jupyter-lab ----------------------------------------------------------------------------------------------------------------
/opt/anaconda3/bin/jupyter lab --ip=${IPADDR} --port=${NB_PORT} --notebook-dir=/home --no-browser --config=${HOME}/.job-log-dir/${SLURM_JOBID}-jupyter_notebook_config.py 
#-----------------------------------------------------------------------------------------------------------------------------------

