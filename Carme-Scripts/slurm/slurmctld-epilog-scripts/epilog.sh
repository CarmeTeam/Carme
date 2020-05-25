#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# notify carme about the job epilog
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


LOG_FILE="/var/log/carme/slurmctld/epilog/${SLURM_JOB_ID}.log"
{ # start command grouping for output redirection

# set PATH -------------------------------------------------------------------------------------------------------------------------
export PATH=${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
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


# define function for output -------------------------------------------------------------------------------------------------------
function log () {
  echo "$(currenttime) ${1}"
}
#-----------------------------------------------------------------------------------------------------------------------------------


log "start slurmctld epilog"


# define function to get variables from CarmeConfig --------------------------------------------------------------------------------
function get_variable () {
  variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
  variable_value=$(echo "${variable_value}" | tr -d '"')
  echo "${variable_value}"
}


# source needed variables
CONFIG_FILE="/opt/Carme/CarmeConfig.backend"
if [[ -f ${CONFIG_FILE} ]];then

  CARME_BACKEND_SERVER=$(get_variable CARME_BACKEND_SERVER ${CONFIG_FILE})
  CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${CONFIG_FILE})
  CARME_SCRIPTS_PATH=$(get_variable CARME_SCRIPTS_PATH ${CONFIG_FILE})

  [[ -z ${CARME_BACKEND_SERVER} ]] && die "CARME_BACKEND_SERVER not set"
  [[ -z ${CARME_BACKEND_PORT} ]] && die "CARME_BACKEND_PORT not set"
  [[ -z ${CARME_SCRIPTS_PATH} ]] && die "CARME_SCRIPTS_PATH not set"

else

  die "${CONFIG_FILE} not found"

fi
#-----------------------------------------------------------------------------------------------------------------------------------


# call notify_job_epilog -----------------------------------------------------------------------------------------------------------
log "run ${CARME_SCRIPTS_PATH}/backend/notify_job_epilog.py"
if ! python3 "${CARME_SCRIPTS_PATH}"/backend/notify_job_epilog.py "${SLURM_JOB_ID}" "${SLURM_JOB_USER}" "${CARME_BACKEND_SERVER}" "${CARME_BACKEND_PORT}"
then
  die "${CARME_SCRIPTS_PATH}/backend/notify_job_epilog.py failed"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


log "finished slurmctld epilog"

} > "${LOG_FILE}" 2>&1

exit 0
