#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Default container startup script
#
# * starts jupyter end tensorboard
# * set env
# 
#-----------------------------------------------------------------------------------------------------------------------------------

IPADDR=${1}
NB_PORT=${2}
TB_PORT=${3}
TA_PORT=${4}
USER=${5}
MYHASH=${6}
GPUS=${7}
MEM=${8}
GPUS_PER_NODE=${9}

#-----------------------------------------------------------------------------------------------------------------------------------
# source needed variables from /home/.CarmeScripts/CarmeConfig.container
CONFIG_FILE="/home/.CarmeScripts/CarmeConfig.container"
if [ -f ${CONFIG_FILE} ];then
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=$(echo "${variable_value}" | tr -d '"')
    echo ${variable_value}
  }
else
  echo "${CONFIG_FILE} not found!"
  exit 137
fi

CARME_VERSION=$(get_variable CARME_VERSION ${CONFIG_FILE})
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
mkdir -p ${TBDIR}

STOREDIR=${HOME}"/.local/share/carme/tmp-files-"${SLURM_JOB_ID}
mkdir -p ${STOREDIR}

JOB_TMP=${HOME}"/.local/share/carme/tmp-files-"${SLURM_JOB_ID}"/tmp_"${SLURM_JOB_ID}
mkdir -p ${JOB_TMP}

LOGDIR=${HOME}"/.local/share/carme/job-log-dir"
OUTFILE=${LOGDIR}"/"${SLURM_JOB_ID}"-"${SLURM_JOB_NAME}".out"
NODELIST=$(grep --color=never -Po "^NODELIST: \K.*" "${OUTFILE}")

# write default bashrc to ${HOME}/.bashrc
cat /home/.CarmeScripts/base_bashrc.sh > ~/.bashrc

# overwrite ${HOME}/.bash_profile to source ${HOME}/.bashrc
echo "
#
# ${HOME}/.bash_profile
#
[[ -f ${HOME}/.bashrc ]] && . ~/.bashrc

" > ${HOME}/.bash_profile

# write conda base environment to file
/opt/anaconda3/bin/conda list >> ${STOREDIR}/conda_base.txt


# find new free sshd port
NEW_SSHD_PORT=""
BASE_PORT="2222"
FINAL_PORT="2300"

for ((i=${BASE_PORT};i<=${FINAL_PORT};i++)); do
  LISTEN=$(ss -tln -4 | grep ${i})
 
  if [ -z "${LISTEN}" ];then
    NEW_SSHD_PORT=${i}
    break
  fi
  
  if [[ "$i" -eq "${FINAL_PORT}" && ! -z "${LISTEN}" ]];then
    echo "ERROR: No free SSHD port found!"
    exit 137
  fi
done


# create ${STOREDIR}/bash_${SLURM_JOB_ID}
echo "# CARME specific exports -----------------------------------------------------------------------------------------------------------
export CARME_VERSION=${CARME_VERSION}
export CARME_TMP=${HOME}"/.local/share/carme/tmp-files-"${SLURM_JOB_ID}"/tmp_"${SLURM_JOB_ID}
export CARME_NODES=${NODELIST}
export CARME_MASTER=${SLURMD_NODENAME}
export CARME_JOBID=${SLURM_JOB_ID}
export CARME_JOB_NAME=${SLURM_JOB_NAME}
export CARME_NUM_NODES=${SLURM_JOB_NUM_NODES}
export CARME_MEM_PER_NODE=${SLURM_MEM_PER_NODE}
export CARME_CPUS_PER_NODE=${SLURM_CPUS_ON_NODE}
export CARME_GPUS_PER_NODE=${GPUS_PER_NODE}
export CARME_GPU_LIST=${CUDA_VISIBLE_DEVICES}
export CARME_ACCOUNT_CLASS=${SLURM_JOB_ACCOUNT}
export CARME_QUEUE=${SLURM_JOB_PARTITION}
export CARME_IMAGE=${SINGULARITY_CONTAINER}
export CARME_BACKEND_SERVER=${CARME_BACKEND_SERVER}
export CARME_BACKEND_PORT=${CARME_BACKEND_PORT}    
export CARME_TENSORBOARD_HOME='${HOME}/tensorboard'
export PATH=\${PATH}:/home/.CarmeScripts/bash/
export TMPDIR=${JOB_TMP}
export TMP=${JOB_TMP}
export TEMP=${JOB_TMP}
#-----------------------------------------------------------------------------------------------------------------------------------


# general exports ------------------------------------------------------------------------------------------------------------------
# modify terminal language settings
export LANG=en_US.utf8
export LC_MESSAGES=POSIX
#-----------------------------------------------------------------------------------------------------------------------------------


# define aliases -------------------------------------------------------------------------------------------------------------------
alias nvidia-smi='nvidia-smi -i ${GPUS}'
alias ls='ls --group-directories-first --color'
alias la='ls -lahv'
alias ld='ls -av'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
#-----------------------------------------------------------------------------------------------------------------------------------
" > ${STOREDIR}/bash_${SLURM_JOB_ID}


#source job bashrc
source ${STOREDIR}/bash_${SLURM_JOB_ID}
#-----------------------------------------------------------------------------------------------------------------------------------


#start additional stuff if we have more than one node or more than one GPU ---------------------------------------------------------
if [[ "${SLURM_JOB_NUM_NODES}" -gt "1" || "${#GPUS}" -gt "1" ]]; then
  # start SSHD
  SSHDIR=${HOME}"/.local/share/carme/tmp-files-"${SLURM_JOB_ID}"/ssh_"${SLURM_JOB_ID}
  mkdir -p ${SSHDIR}
  ssh-keygen -t ssh-rsa -N "" -f ${SSHDIR}/server_key_${SLURM_JOB_ID}
  ssh-keygen -t rsa -N "" -f ${HOME}/.ssh/id_rsa_${SLURM_JOB_ID}
  mv ${HOME}/.ssh/id_rsa_${SLURM_JOB_ID}.pub ${SSHDIR}/id_rsa_${SLURM_JOB_ID}.pub
  cat ${SSHDIR}/id_rsa_${SLURM_JOB_ID}.pub >> ${SSHDIR}/authorized_keys_${SLURM_JOB_ID}

  echo "PermitRootLogin no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
AuthorizedKeysFile ${SSHDIR}/authorized_keys_${SLURM_JOB_ID}
LoginGraceTime 30s
MaxAuthTries 3
ClientAliveInterval 3600
ClientAliveCountMax 1
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_* CUDA* ENVIRONMENT GIT* GPU_DEVICE_ORDINAL HASH HOSTNAME JUPYTER_DATA LD_LIBRARY_PATH SINGULARITY* SLURM* S_COLORS TBDIR XGD_RUNTIME_DIR
AllowUsers ${USER}
PermitUserEnvironment no
" >> ${SSHDIR}/sshd_config_${SLURM_JOB_ID}
		chmod 640 ${SSHDIR}/sshd_config_${SLURM_JOB_ID}

  rm ${HOME}/.ssh/known_hosts
  
		echo "SendEnv LANG LC_* CUDA* ENVIRONMENT GIT* GPU_DEVICE_ORDINAL HASH HOSTNAME JUPYTER_DATA LD_LIBRARY_PATH SINGULARITY* SLURM* S_COLORS TBDIR XGD_RUNTIME_DIR
HashKnownHosts yes
GSSAPIAuthentication yes
CheckHostIP no
StrictHostKeyChecking no
 
Host $(hostname)
  HostName $(hostname)
  User ${USER}
  Port ${NEW_SSHD_PORT}
  IdentityFile ${HOME}/.ssh/id_rsa_${SLURM_JOB_ID}
  
" >> ${SSHDIR}/ssh_config_${SLURM_JOB_ID}

  chmod 640 ${HOME}/.ssh/config		
  
  echo "starting SSHD on MASTER" $(hostname)
  /usr/sbin/sshd -p ${NEW_SSHD_PORT} -D -h ${SSHDIR}/server_key_${SLURM_JOB_ID} -E ${SSHDIR}/sshd_log_${SLURM_JOB_ID} -f ${SSHDIR}/sshd_config_${SLURM_JOB_ID} &
  
		echo "alias ssh='ssh -F ${SSHDIR}/ssh_config_${SLURM_JOB_ID}'" >> ${STOREDIR}/bash_${SLURM_JOB_ID}
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# start tensorboard ----------------------------------------------------------------------------------------------------------------
TENSORBOARD_LOG_DIR="${TBDIR}/tensorboard_${SLURM_JOB_ID}"
mkdir ${TENSORBOARD_LOG_DIR}
LC_ALL=C /opt/anaconda3/bin/tensorboard --logdir=${TENSORBOARD_LOG_DIR} --port=${TB_PORT} --path_prefix="/tb_${MYHASH}" & 
#-----------------------------------------------------------------------------------------------------------------------------------


# start theia ----------------------------------------------------------------------------------------------------------------------
THEIA_BASE_DIR="/opt/theia-ide/"
if [ -d ${THEIA_BASE_DIR} ]; then
  cd ${THEIA_BASE_DIR}
  PATH=/opt/anaconda3/bin/:${PATH} TMPDIR=${JOB_TMP} TMP=${JOB_TMP} TEMP=${JOB_TMP} /opt/anaconda3/bin/node node_modules/.bin/theia start ${HOME} --hostname ${IPADDR} --port ${TA_PORT} --startup-timeout -1 &
  cd
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# start jupyter-lab ----------------------------------------------------------------------------------------------------------------
/opt/anaconda3/bin/jupyter lab --ip=${IPADDR} --port=${NB_PORT} --notebook-dir=/home --no-browser --config=${STOREDIR}/jupyter_notebook_config-${SLURM_JOB_ID}.py &
#-----------------------------------------------------------------------------------------------------------------------------------


# wait until the job is done -------------------------------------------------------------------------------------------------------
wait
#-----------------------------------------------------------------------------------------------------------------------------------

