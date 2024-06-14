#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# notify carme about the job epilog
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


# variables ------------------------------------------------------------------------------------------------------------------------
CONFIG_FILE="/etc/carme/CarmeConfig.backend"
#-----------------------------------------------------------------------------------------------------------------------------------


LOG_FILE="/var/log/carme/slurmctld/epilog/${SLURM_JOB_ID}.log"
{ # start command grouping for output redirection

# set PATH -------------------------------------------------------------------------------------------------------------------------
export PATH=/opt/Carme/Carme-Vendors/mambaforge/envs/carme-backend/bin:${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#-----------------------------------------------------------------------------------------------------------------------------------


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


# define function that checks if a command is available or not ---------------------------------------------------------------------
function check_command () {
  if ! command -v "${1}" >/dev/null 2>&1 ;then
    die "command '${1}' not found"
  fi
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function for output -------------------------------------------------------------------------------------------------------
function log () {
  echo "$(currenttime) ${1}"
}
#-----------------------------------------------------------------------------------------------------------------------------------


log "start slurmctld epilog"


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command grep
check_command python3
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to get variables from CarmeConfig --------------------------------------------------------------------------------
function get_variable () {
  variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
  variable_value=$(echo "${variable_value}" | tr -d '"')
  echo "${variable_value}"
}


# source needed variables
if [[ -f ${CONFIG_FILE} ]];then

  CARME_BACKEND_SERVER=$(get_variable CARME_BACKEND_SERVER ${CONFIG_FILE})
  CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${CONFIG_FILE})
  CARME_PATH_SCRIPTS=$(get_variable CARME_PATH_SCRIPTS ${CONFIG_FILE})

  [[ -z ${CARME_BACKEND_SERVER} ]] && die "CARME_BACKEND_SERVER not set."
  [[ -z ${CARME_BACKEND_PORT} ]] && die "CARME_BACKEND_PORT not set."
  [[ -z ${CARME_PATH_SCRIPTS} ]] && die "CARME_PATH_SCRIPTS not set."

else

  die "${CONFIG_FILE} not found"

fi
#-----------------------------------------------------------------------------------------------------------------------------------


# call notify_job_epilog -----------------------------------------------------------------------------------------------------------
log "run ${CARME_PATH_SCRIPTS}/backend/notify_job_epilog.py"
#if ! python3 "${CARME_SCRIPTS_PATH}"/backend/notify_job_epilog.py "${SLURM_JOB_ID}" "${SLURM_JOB_USER}" "${CARME_BACKEND_SERVER}" "${CARME_BACKEND_PORT}"
#then
#  die "${CARME_SCRIPTS_PATH}/backend/notify_job_epilog.py failed"
#fi
#-----------------------------------------------------------------------------------------------------------------------------------


log "finished slurmctld epilog"

} > "${LOG_FILE}" 2>&1

exit 0
