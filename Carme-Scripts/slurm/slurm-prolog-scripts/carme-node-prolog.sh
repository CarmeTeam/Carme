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


# source needed variables from /home/.CarmeScripts/CarmeConfig.container -----------------------------------------------------------
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
CARME_SCRIPT_PATH=$(get_variable CARME_SCRIPT_PATH "${CONFIG_FILE}")
CARME_START_SSHD=$(get_variable CARME_START_SSHD "${CONFIG_FILE}")
CARME_VERSION=$(get_variable CARME_VERSION "${CONFIG_FILE}")
CARME_URL=$(get_variable CARME_URL "${CONFIG_FILE}")

[[ -z ${CARME_DISTRIBUTED_FS} ]] && die "CARME_DISTRIBUTED_FS not set"
[[ -z ${CARME_LOCAL_SSD_PATH} ]] && die "CARME_LOCAL_SSD_PATH not set"
[[ -z ${CARME_GATEWAY} ]] && die "CARME_GATEWAY not set"
[[ -z ${CARME_BACKEND_SERVER} ]] && die "CARME_BACKEND_SERVER not set"
[[ -z ${CARME_BACKEND_PORT} ]] && die "CARME_BACKEND_PORT not set"
[[ -z ${CARME_SCRIPT_PATH} ]] && die "CARME_SCRIPT_PATH not set"
[[ -z ${CARME_START_SSHD} ]] && die "CARME_START_SSHD not set"
[[ -z ${CARME_VERSION} ]] && die "CARME_VERSION not set"
[[ -z ${CARME_URL} ]] && die "CARME_URL not set"
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

  log "create ${JOBDIR}/tmp"
  mkdir -p "${JOBDIR}/tmp" || die "cannot create ${JOBDIR}/tmp"

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
export CARME_TMP=${JOBDIR}/tmp
export TMPDIR=${JOBDIR}/tmp
export TMP=${JOBDIR}/tmp
export TEMP=${JOBDIR}/tmp


# CARME specific exports -----------------------------------------------------------------------------------------------------------
export PATH=\${PATH}:/home/.CarmeScripts/bash
export CARME_URL=\"https://${CARME_URL}\"
export CARME_VERSION=${CARME_VERSION}
export CARME_IMAGE_NAME=\${SINGULARITY_CONTAINER}
export CARME_NODES=$(scontrol show hostname "${NODE_LIST}" | paste -d, -s)
export CARME_MASTER=${MASTER_NODE}
export CARME_START_SSHD=${CARME_START_SSHD}
export CARME_LOCAL_SSD_PATH=${CARME_LOCAL_SSD_PATH}
" > "${JOBDIR}/bashrc"


  #compute ports: base port + first GPU id
  JOB_OFFSET=${SLURM_JOB_ID:${#SLURM_JOB_ID}<3?0:-3}
  PORT_OFFSET="1000"

  NB_PORT="$((6000 + 10#$JOB_OFFSET))"
  log "jupyterlab port: ${NB_PORT}"

  TB_PORT="$((NB_PORT + PORT_OFFSET))"
  log "tensorboard port: ${TB_PORT}"

  TA_PORT="$((NB_PORT + PORT_OFFSET + PORT_OFFSET))"
  log "theia port: ${TA_PORT}"

  log "create ${JOBDIR}/ports/$(hostname)"
  echo "export NB_PORT=${NB_PORT}
export TB_PORT=${TB_PORT}
export TA_PORT=${TA_PORT}" >> "${JOBDIR}/ports/$(hostname)"

  if ss -tln -4 | grep -q ${NB_PORT}
  then
    die "no free port for entrypoints found for NB_PORT (${NB_PORT})"
  fi

  if ss -tln -4 | grep -q ${TB_PORT}
  then
    die "no free port for entrypoints found for NB_PORT (${TB_PORT})"
  fi

  if ss -tln -4 | grep -q ${TA_PORT}
  then
    die "no free port for entrypoints found for NB_PORT (${TA_PORT})"
  fi


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
    ssh-keygen -t rsa -N "" -f "${USER_HOME}/.ssh/id_rsa_${SLURM_JOB_ID}"
    chown "${SLURM_JOB_USER}":"${USER_GROUP}" "${USER_HOME}/.ssh/id_rsa_${SLURM_JOB_ID}"
    mv "${USER_HOME}/.ssh/id_rsa_${SLURM_JOB_ID}.pub" "${JOBDIR}/ssh/id_rsa_${SLURM_JOB_ID}.pub"
    cat "${JOBDIR}/ssh/id_rsa_${SLURM_JOB_ID}.pub" >> "${JOBDIR}/ssh/authorized_keys"


    # create sshd and ssh config
    log "create sshd config"

    echo "PermitRootLogin no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
AuthorizedKeysFile ${JOBDIR}/ssh/authorized_keys
LoginGraceTime 30s
MaxAuthTries 3
ClientAliveInterval 3600
ClientAliveCountMax 1
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_* SLURM_JOB_ID ENVIRONMENT GIT* XDG_RUNTIME_DIR
AllowUsers ${SLURM_JOB_USER}
PermitUserEnvironment no
" >> "${JOBDIR}/ssh/sshd_config"
    chmod 640 "${JOBDIR}/ssh/sshd_config"

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
  runuser -u "${SLURM_JOB_USER}" -- "${CARME_SCRIPT_PATH}"/dist_alter_jobDB_entry/alter_jobDB_entry "unused_url" "${SLURM_JOB_ID}" "${HASH}" "${IPADDR}" "${NB_PORT}" "${TB_PORT}" "${TA_PORT}" "${CUDA_VISIBLE_DEVICES}" "${CARME_BACKEND_SERVER}" "${CARME_BACKEND_PORT}"

fi
#-----------------------------------------------------------------------------------------------------------------------------------


# create ssh:config.d files --------------------------------------------------------------------------------------------------------
if [[ "${CARME_START_SSHD}" == "always" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1") ]];then

  log "create ${JOBDIR}/ports"
  mkdir -p "${JOBDIR}/ports" || die "cannot create ${JOBDIR}/ports"

  log "create ${JOBDIR}/ssh/ssh_config.d"
  mkdir -p "${JOBDIR}/ssh/ssh_config.d" || die "cannot create ${JOBDIR}/ssh/ssh_config.d"

  # find new free sshd port
  SSHD_PORT=""
  BASE_PORT="2222"
  FINAL_PORT="2300"

  for ((i=BASE_PORT;i<=FINAL_PORT;i++)); do
    if ! ss -tln -4 | grep -q "${i}"
    then
      SSHD_PORT=${i}
      echo "export SSHD_PORT=${SSHD_PORT}" >> "${JOBDIR}/ports/$(hostname)"
      log "sshd port: ${SSHD_PORT}"
      chown "${SLURM_JOB_USER}":"${USER_GROUP}" "${JOBDIR}/ports/$(hostname)"
      break
    fi

    if [[ "$i" -eq "${FINAL_PORT}" && -n "${LISTEN}" ]];then
      die "no free SSHD port found!"
    fi
  done

  log "create node specific ssh config"
  echo "Host $(hostname)
  HostName $(hostname)
  User ${SLURM_JOB_USER}
  Port ${SSHD_PORT}
  IdentityFile ${USER_HOME}/.ssh/id_rsa_${SLURM_JOB_ID}
" >> "${JOBDIR}/ssh/ssh_config.d/$(hostname)"

  log "change ownership of ${JOBDIR}"
  chown -R "${SLURM_JOB_USER}":"${USER_GROUP}" "${JOBDIR}"

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
