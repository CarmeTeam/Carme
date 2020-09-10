#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# this script is executed on each compute to set up the needed carme infrastrcture
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# do nothing if this is not a carme job --------------------------------------------------------------------------------------------
if ! [[ "${SLURM_JOB_CONSTRAINTS}" =~ "carme" ]];then
  exit 0
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to print time and date -------------------------------------------------------------------------------------------
function currenttime () {
  date +"[%F %T.%3N]"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define logfile -------------------------------------------------------------------------------------------------------------------
LOG_FILE="/var/log/carme/slurmd/prolog/${SLURM_JOB_ID}.log"
{ # start command grouping for output redirection
echo "$(currenttime) start slurm prolog"
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "$(currenttime) ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function for output -------------------------------------------------------------------------------------------------------
function log () {
  echo "$(currenttime) ${1}"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to get new ports for entry points --------------------------------------------------------------------------------
# usage: get_free_port "PORT_START" "PORT_END" "VARIABLE_FOR_PORT_TO_BE_SET"
# NOTE: make sure that the range (PORT_END - PORT_START) is a power of 2 and not smaller than 1024!
function get_free_port () {
  local TRIES
  TRIES=()

  for ((i=1;i<=10;i++)); do

    local NEW_PORT
    local SEED

    SEED="$(od -An -N4 -t u4 < /dev/urandom)"
    NEW_PORT="$(( SEED % (${2} - ${1}) + ${1} ))"
    TRIES+=("${NEW_PORT} (seed ${SEED})")

    if ! ss -tln -4 | grep -q "${NEW_PORT}"
    then
      echo "export ${3}=${NEW_PORT}" >> "${JOBDIR}/ports/$(hostname)"
      log "${3}: ${NEW_PORT}"
      export ${3}=${NEW_PORT}
      break
    fi

    if [[ "${i}" -eq "10" ]];then
      echo ""
      echo "tried 10 times to find a free port but failed"
      for TRY in "${TRIES[@]}";do
        echo "${TRY}"
      done
      die "no free ${3}"
    fi
  done
}
#-----------------------------------------------------------------------------------------------------------------------------------


# source needed variables ----------------------------------------------------------------------------------------------------------
CONFIG_FILE="/opt/Carme/Carme-Scripts/InsideContainer/CarmeConfig.container"
if [ -f ${CONFIG_FILE} ];then
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=$(echo "${variable_value}" | tr -d '"')
    echo "${variable_value}"
  }
else
  die "${CONFIG_FILE} not found"
fi

CARME_DISTRIBUTED_FS=$(get_variable CARME_DISTRIBUTED_FS "${CONFIG_FILE}")
CARME_LOCAL_SSD_PATH=$(get_variable CARME_LOCAL_SSD_PATH "${CONFIG_FILE}")
CARME_GATEWAY=$(get_variable CARME_GATEWAY "${CONFIG_FILE}")
CARME_BACKEND_SERVER=$(get_variable CARME_BACKEND_SERVER "${CONFIG_FILE}")
CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT "${CONFIG_FILE}")
CARME_SCRIPTS_PATH=$(get_variable CARME_SCRIPTS_PATH "${CONFIG_FILE}")
CARME_START_SSHD=$(get_variable CARME_START_SSHD "${CONFIG_FILE}")
CARME_VERSION=$(get_variable CARME_VERSION "${CONFIG_FILE}")
CARME_URL=$(get_variable CARME_URL "${CONFIG_FILE}")
CARME_TMPDIR=$(get_variable CARME_TMPDIR "${CONFIG_FILE}")

[[ -z ${CARME_DISTRIBUTED_FS} ]] && die "CARME_DISTRIBUTED_FS not set"
[[ -z ${CARME_LOCAL_SSD_PATH} ]] && die "CARME_LOCAL_SSD_PATH not set"
[[ -z ${CARME_GATEWAY} ]] && die "CARME_GATEWAY not set"
[[ -z ${CARME_BACKEND_SERVER} ]] && die "CARME_BACKEND_SERVER not set"
[[ -z ${CARME_BACKEND_PORT} ]] && die "CARME_BACKEND_PORT not set"
[[ -z ${CARME_SCRIPTS_PATH} ]] && die "CARME_SCRIPTS_PATH not set"
[[ -z ${CARME_START_SSHD} ]] && die "CARME_START_SSHD not set"
[[ -z ${CARME_VERSION} ]] && die "CARME_VERSION not set"
[[ -z ${CARME_URL} ]] && die "CARME_URL not set"
[[ -z ${CARME_TMPDIR} ]] && die "CARME_TMPDIR not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# create job folder skeleton -------------------------------------------------------------------------------------------------------
MASTER_NODE="$(scontrol show job "${SLURM_JOB_ID}" | grep BatchHost | cut -d "=" -f 2 | cut -d/ -f1)"
log "master node: ${MASTER_NODE}"
log "distributed file system: ${CARME_DISTRIBUTED_FS}"

if [[ "$(hostname)" == "${MASTER_NODE}" && "${CARME_DISTRIBUTED_FS}" == "yes" ]];then
  CARME_NODEID="0"
elif [[ "${CARME_DISTRIBUTED_FS}" == "no" ]];then
  CARME_NODEID="0"
fi


# define the users home directory and its primary group
USER_HOME="$(getent passwd "${SLURM_JOB_USER}" | cut -d: -f6)"
[[ -z "${USER_HOME}" ]] && die "home-folder of user ${SLURM_JOB_USER} not set"
[[ ! -d "${USER_HOME}" ]] && die "home-folder (${USER_HOME}) of user ${SLURM_JOB_USER} does not exist"
log "slurm-user: ${SLURM_JOB_USER}"
log "slurm-user home: ${USER_HOME}"


USER_GROUP=$(id -gn "${SLURM_JOB_USER}")
[[ -z "${USER_GROUP}" ]] && die "main group of ${SLURM_JOB_USER} not set"
log "slurm-user group: ${USER_GROUP}"


# get job nodelist, number of nodes and number of gpus
NODE_LIST=$(scontrol show job "${SLURM_JOB_ID}" | grep -w NodeList | awk -F'=' '{ print $2 }')
log "job nodes: ${NODE_LIST}"

NUMBER_OF_NODES=$(scontrol show hostnames "${NODE_LIST}" | wc -l)


# set the primariy folders that have to be created
LOGDIR="${USER_HOME}/.local/share/carme/job-log-dir"
JOBDIR="${USER_HOME}/.local/share/carme/job/${SLURM_JOB_ID}"
JUPYTERLAB_BASEDIR="${JOBDIR}/jupyter"
JUPYTERLAB_WORKSPACESDIR="${JUPYTERLAB_BASEDIR}/workspaces"


if [[ "${CARME_NODEID}" == "0" ]];then

  # create the primary folders
  log "create ${LOGDIR}"
  mkdir -p "${LOGDIR}" || die "cannot create ${LOGDIR}"

  log "create ${JOBDIR}"
  mkdir -p "${JOBDIR}" || die "cannot create ${JOBDIR}"

  log "create ${JOBDIR}/tensorboard"
  mkdir -p "${JOBDIR}/tensorboard" || die "cannot create ${JOBDIR}/tensorboard"

  log "create ${JOBDIR}/ports"
  mkdir -p "${JOBDIR}/ports" || die "cannot create ${JOBDIR}/ports"

  log "create ${JUPYTERLAB_BASEDIR}"
  mkdir -p "${JUPYTERLAB_BASEDIR}" || die "cannot create ${JUPYTERLAB_BASEDIR}"

  log "create ${JUPYTERLAB_WORKSPACESDIR}"
  mkdir -p "${JUPYTERLAB_WORKSPACESDIR}" || die "cannot create ${JUPYTERLAB_WORKSPACESDIR}"

  # create job-specific bashrc
  log "create ${JOBDIR}/bashrc"

  echo "# modify terminal language settings ------------------------------------------------------------------------------------------------
export LANG=en_US.utf8
export LC_MESSAGES=POSIX
#-----------------------------------------------------------------------------------------------------------------------------------


# CARME specific folders -----------------------------------------------------------------------------------------------------------
export CARME_LOGDIR=${LOGDIR}
export CARME_JOBDIR=${JOBDIR}
export CARME_SSHDIR=${JOBDIR}/ssh
export CARME_PORTSDIR=${JOBDIR}/ports
export CARME_JUPYTERLAB_WORKSPACESDIR=${JUPYTERLAB_WORKSPACESDIR}
export CARME_TBDIR=${JOBDIR}/tensorboard
export CARME_TMPDIR=${CARME_TMPDIR}


# CARME specific exports -----------------------------------------------------------------------------------------------------------
export PATH=\${PATH}:/home/.CarmeScripts/bash
export CARME_URL=\"https://${CARME_URL}\"
export CARME_VERSION=${CARME_VERSION}
export CARME_IMAGE_NAME=\${SINGULARITY_CONTAINER}
export CARME_NODES=$(scontrol show hostname "${NODE_LIST}" | paste -d, -s)
export CARME_MASTER=${MASTER_NODE}
export CARME_START_SSHD=${CARME_START_SSHD}
export CARME_LOCAL_SSD_PATH=${CARME_LOCAL_SSD_PATH}
export CARME_JOB_ID=${SLURM_JOB_ID}
export CARME_JOB_NAME=$(scontrol show job "${SLURM_JOB_ID}" | grep JobName | awk -F'JobName=' '{ print $2 }')
export CARME_JOB_GPUS=${SLURM_JOB_GPUS}
" > "${JOBDIR}/bashrc"


  # create ssh stuff if needed
  if [[ "${CARME_START_SSHD}" == "always" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1") ]];then

    # create folders needed for ssh
    if [[ ! -d "${USER_HOME}/.ssh" ]];then
      mkdir "${USER_HOME}/.ssh"
      chown "${SLURM_JOB_USER}":"${USER_GROUP}" "${USER_HOME}/.ssh"
    fi

    log "create ${JOBDIR}/ssh"
    mkdir -p "${JOBDIR}/ssh" || die "cannot create ${JOBDIR}/ssh"

    log "create ${JOBDIR}/ssh/ssh_config.d"
    mkdir -p "${JOBDIR}/ssh/ssh_config.d" || die "cannot create ${JOBDIR}/ssh/ssh_config.d"

    log "create ${JOBDIR}/ssh/envs"
    mkdir -p "${JOBDIR}/ssh/envs" || die "cannot create ${JOBDIR}/ssh/envs"

    # create ssh keys
    log "create ssh keys"

    ssh-keygen -t ssh-rsa -N "" -f "${JOBDIR}/ssh/server_key"
    ssh-keygen -t rsa -N "" -f "${JOBDIR}/ssh/id_rsa_${SLURM_JOB_ID}"
    cat "${JOBDIR}/ssh/id_rsa_${SLURM_JOB_ID}.pub" >> "${JOBDIR}/ssh/authorized_keys"


    # create ssh config
    log "create ssh config"
    echo "SendEnv LANG LC_* SLURM_JOB_ID ENVIRONMENT GIT* XDG_RUNTIME_DIR
HashKnownHosts yes
GSSAPIAuthentication yes
CheckHostIP no
StrictHostKeyChecking no
UserKnownHostsFile ${JOBDIR}/ssh/known_hosts

Include ${JOBDIR}/ssh/ssh_config.d/*
" >> "${JOBDIR}/ssh/ssh_config"

    echo "alias ssh='ssh -F ${JOBDIR}/ssh/ssh_config'" >> "${JOBDIR}/bashrc"
  fi


  # change ownership of the new folders to the right user
  log "change ownership of ${LOGDIR}"
  chown -R "${SLURM_JOB_USER}":"${USER_GROUP}" "${LOGDIR}"

  log "change ownership of ${USER_HOME}/.local/share/carme/job"
  chown "${SLURM_JOB_USER}":"${USER_GROUP}" "${USER_HOME}/.local/share/carme/job"

  log "change ownership of ${JOBDIR}"
  chown -R "${SLURM_JOB_USER}":"${USER_GROUP}" "${JOBDIR}"

fi
#-----------------------------------------------------------------------------------------------------------------------------------


# do only once on master node ------------------------------------------------------------------------------------------------------
if [[ "$(hostname)" == "${MASTER_NODE}" ]];then

  #determine jupyterlab port
  get_free_port "6000" "7000" "NB_PORT"

  #determine theia-ide port
  get_free_port "7001" "8000" "TA_PORT"

  #determine tensorboard port
  get_free_port "8001" "9000" "TB_PORT"

  # get IP of master node and create hash
  IPADDR="$(ip route get "${CARME_GATEWAY}" | head -1 | awk '{print $5}' | cut -d/ -f1)"
  log "master node ip address: ${IPADDR}"

  HASH="$(head /dev/urandom | tr -dc a-z0-9 | head -c 30)"
  log "job hash: ${HASH}"

  echo "export CARME_MASTER_IP=${IPADDR}
export CARME_HASH=${HASH}
" >> "${JOBDIR}/bashrc"

  #register job with frontend db
  log "register job with frontend db"
  runuser -u "${SLURM_JOB_USER}" -- "${CARME_SCRIPTS_PATH}/frontend/dist_alter_jobDB_entry/alter_jobDB_entry" "unused_url" "${SLURM_JOB_ID}" "${HASH}" "${IPADDR}" "${NB_PORT}" "${TB_PORT}" "${TA_PORT}" "${SLURM_JOB_GPUS}" "${CARME_BACKEND_SERVER}" "${CARME_BACKEND_PORT}"

fi
#-----------------------------------------------------------------------------------------------------------------------------------


# create ssh:config.d files --------------------------------------------------------------------------------------------------------
if [[ "${CARME_START_SSHD}" == "always" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1") ]];then

  # create folder for sshd_configs
  log "create ${JOBDIR}/ssh/sshd"
  mkdir -p "${JOBDIR}/ssh/sshd" || die "cannot create ${JOBDIR}/ssh/sshd"

  # create node specific sshd_configs
  log "create sshd config for $(hostname)"

  echo "PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
AuthorizedKeysFile ${JOBDIR}/ssh/authorized_keys
PidFile ${JOBDIR}/ssh/sshd/$(hostname).pid
LoginGraceTime 30s
MaxAuthTries 3
ClientAliveInterval 60
ClientAliveCountMax 3
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_* SLURM_JOB_ID ENVIRONMENT GIT* XDG_RUNTIME_DIR
AllowUsers ${SLURM_JOB_USER}
PermitUserEnvironment no
" >> "${JOBDIR}/ssh/sshd/$(hostname).conf"
  chmod 640 "${JOBDIR}/ssh/sshd/$(hostname).conf"

  # create folder for ports
  log "create ${JOBDIR}/ports"
  mkdir -p "${JOBDIR}/ports" || die "cannot create ${JOBDIR}/ports"

  # create folder for local ssh_configs
  log "create ${JOBDIR}/ssh/ssh_config.d"
  mkdir -p "${JOBDIR}/ssh/ssh_config.d" || die "cannot create ${JOBDIR}/ssh/ssh_config.d"

  # find new free sshd port
  get_free_port "2000" "3000" "SSHD_PORT"

  log "create node specific ssh config"
  echo "Host $(hostname)
  HostName $(hostname)
  User ${SLURM_JOB_USER}
  Port ${SSHD_PORT}
  IdentityFile ${JOBDIR}/ssh/id_rsa_${SLURM_JOB_ID}
" >> "${JOBDIR}/ssh/ssh_config.d/$(hostname)"

  log "change ownership of ${JOBDIR}"
  chown -R "${SLURM_JOB_USER}":"${USER_GROUP}" "${JOBDIR}"

fi
#-----------------------------------------------------------------------------------------------------------------------------------


# create a tmp folder for this job -------------------------------------------------------------------------------------------------
if [[ -d "${CARME_TMPDIR}" ]];then
  log "create job tmp directory ${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname)"
  mkdir "${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname)"

  log "change ownership of ${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname)"
  chown -R "${SLURM_JOB_USER}":"${USER_GROUP}" "${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname)"
else
  die "cannot access CARME_TMPDIR=\"${CARME_TMPDIR}\" to create job tmp directory"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# create a folder on the local SSD (if available) ----------------------------------------------------------------------------------
if [[ -n ${CARME_LOCAL_SSD_PATH} && -d ${CARME_LOCAL_SSD_PATH} ]];then

  log "create ${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}"
  mkdir -p "${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}" || die "cannot create ${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}"

  echo "/home/SSD is a mount point to an SSD installed on this node ($(hostname)) and not available via network.

NOTE: This folder only exists as long as your job is running. As soon as it is completed, all data in it will be deleted!
      Remember to copy relevant results before your job ends as this folder cannot be restored afterwards!
" >> "${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}/README.md"

  log "change ownership of ${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}"
  chown -R "${SLURM_JOB_USER}":"${USER_GROUP}" "${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}"

else

  if [[ -z ${CARME_LOCAL_SSD_PATH} ]];then
    echo "$(currenttime) ERROR: CARME_LOCAL_SSD_PATH not set"
  elif [[ ! -d ${CARME_LOCAL_SSD_PATH} ]];then
    echo "$(currenttime) ERROR: CARME_LOCAL_SSD_PATH does not exist."
  elif [[ -z ${CARME_LOCAL_SSD_PATH} && -d ${CARME_LOCAL_SSD_PATH} ]];then
    echo "$(currenttime) ERROR: CARME_LOCAL_SSD_PATH not set and path does not exist"
  fi

fi
#-----------------------------------------------------------------------------------------------------------------------------------

echo "$(currenttime) completed slurm prolog"
} > "${LOG_FILE}" 2>&1 # end command grouping for output redirection

exit 0
