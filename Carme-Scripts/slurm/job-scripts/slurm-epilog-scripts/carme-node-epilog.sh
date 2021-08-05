#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# This script will kill any user processes on a node when the last
# SLURM job there ends. For example, if a user directly logs into
# an allocated node SLURM will not kill that process without this
# script being executed as an epilog.
#-----------------------------------------------------------------------------------------------------------------------------------

# SLURM_BIN can be used for testing with private version of SLURM ------------------------------------------------------------------
#SLURM_BIN="/usr/bin/"
#-----------------------------------------------------------------------------------------------------------------------------------

set -e # stop after error
set -o pipefail # stop if command in pipe failed


# define function to print time and date -------------------------------------------------------------------------------------------
function currenttime () {
  date +"[%F %T.%3N]"
}
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


# define function that checks if a command is available or not ---------------------------------------------------------------------
function check_command () {
  if ! command -v "${1}" >/dev/null 2>&1 ;then
    die "command '${1}' not found"
  fi
}
#-----------------------------------------------------------------------------------------------------------------------------------


# do nothing if this is not a carme job --------------------------------------------------------------------------------------------
PROLOG_LOG_FILE="/var/log/carme/slurmd/prolog/${SLURM_JOB_ID}.log"
if [[ ! -f "${PROLOG_LOG_FILE}" ]];then
  exit 0
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# define logfile -------------------------------------------------------------------------------------------------------------------
LOG_DIR="/var/log/carme/slurmd/epilog"
mkdir -p "${LOG_DIR}" || die "cannot create ${LOG_DIR}"

LOG_FILE="${LOG_DIR}/${SLURM_JOB_ID}.log"
{ # start command grouping for output redirection
echo "$(currenttime) start slurm epilog"
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command grep
check_command scontrol
check_command hostname
#-----------------------------------------------------------------------------------------------------------------------------------


# check if something has to be done ------------------------------------------------------------------------------------------------
[[ -z "${SLURM_JOB_USER}" || -z "${SLURM_JOB_ID}" ]] && die "SLURM_JOB_USER or SLURM_JOB_ID not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# Don't try to kill user root or system daemon jobs --------------------------------------------------------------------------------
[[ -z "${SYS_UID_MAX}" ]] && SYS_UID_MAX=999

[[ "${SLURM_JOB_UID}" -lt "${SYS_UID_MAX}" ]] && die "SLURM_JOB_UID (${SLURM_JOB_UID}) is lower than SYS_UID_MAX (${SYS_UID_MAX})"
#-----------------------------------------------------------------------------------------------------------------------------------


# delete CARME specific files and folders ------------------------------------------------------------------------------------------

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

CARME_DISTRIBUTED_FS=$(get_variable CARME_DISTRIBUTED_FS ${CONFIG_FILE})
CARME_LOCAL_SSD_PATH=$(get_variable CARME_LOCAL_SSD_PATH ${CONFIG_FILE})
CARME_TMPDIR=$(get_variable CARME_TMPDIR "${CONFIG_FILE}")

[[ -z ${CARME_DISTRIBUTED_FS} ]] && die "CARME_DISTRIBUTED_FS not set"
[[ -z ${CARME_TMPDIR} ]] && die "CARME_TMPDIR not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# remove carme specific files and folders ------------------------------------------------------------------------------------------
MASTER_NODE=$(scontrol show job "${SLURM_JOB_ID}" | grep BatchHost | cut -d "=" -f 2 | cut -d/ -f1)
log "master node: ${MASTER_NODE}"
log "distributed file system: ${CARME_DISTRIBUTED_FS}"

if [[ "$(hostname -s)" == "${MASTER_NODE}" && "${CARME_DISTRIBUTED_FS}" == "yes" ]];then
  CARME_NODEID="0"
elif [[ "${CARME_DISTRIBUTED_FS}" == "no" ]];then
  CARME_NODEID="0"
fi

if [[ "${CARME_NODEID}" == "0" ]];then

  USER_HOME=$(getent passwd "${SLURM_JOB_USER}" | cut -d: -f6)
  [[ -z "${USER_HOME}" ]] && die "home-folder of ${SLURM_JOB_USER} not set"
  log "slurm-user: ${SLURM_JOB_USER}"
  log "slurm-user home: ${USER_HOME}"

  # remove job specific stuff
  CARME_JOBDIR="${USER_HOME}/.local/share/carme/job/${SLURM_JOB_ID}"
  if [[ -d "${CARME_JOBDIR}" ]];then
    log "remove ${CARME_JOBDIR}"
    rm -r "${CARME_JOBDIR}"
  fi

fi


# delete job tmp folder
if [[ -d "${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname -s)" ]];then
  log "remove ${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname -s)"
  rm -r "${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname -s)"
fi


# delete local scratch folder
if [[ -n ${CARME_LOCAL_SSD_PATH} && -d "${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}" ]];then
  log "remove ${CARME_LOCAL_SSD_PATH:?}/${SLURM_JOB_ID}"
  rm -r "${CARME_LOCAL_SSD_PATH:?}/${SLURM_JOB_ID}"
fi
#-----------------------------------------------------------------------------------------------------------------------------------

echo "$(currenttime) completed slurm epilog"
} > "${LOG_FILE}" 2>&1 # end command grouping for output redirection

exit 0
