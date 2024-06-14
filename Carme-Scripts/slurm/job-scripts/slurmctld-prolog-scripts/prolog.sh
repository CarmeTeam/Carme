#!/bin/bash
#-----------------------------------------------------------------------------------------#
#-------------------------------- Slurmctld Prolog ---------------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# job constraint --------------------------------------------------------------------------
if [[ "${SLURM_JOB_CONSTRAINTS}" =~ "carme" ]]; then
    
  ################################## basic funtions #######################################
  # show time -----------------------------------------------------------------------------
  function currenttime () {
    date +"[%F %T.%3N]"
  }

  # log message ---------------------------------------------------------------------------
  function log () {
    echo "$(currenttime) ${1}"
  }

  # error message -------------------------------------------------------------------------
  function die () {
    echo "$(currenttime) ERROR ${1}"
    exit 200
  }

  # check command -------------------------------------------------------------------------
  function check_command () {
    if ! command -v "${1}" >/dev/null 2>&1 ;then
      die "command '${1}' not found"
    fi
  }

  # get variable --------------------------------------------------------------------------
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=$(echo "${variable_value}" | tr -d '"')
    echo "${variable_value}" 
  }

  # variables -----------------------------------------------------------------------------
  FILE_BACKEND_CONFIG="/etc/carme/CarmeConfig.backend"
  FILE_SLURMCTLD_PROLOG="/var/log/carme/slurmctld/prolog/${SLURM_JOB_ID}.log"
  PATH_CARME_BACKEND_BIN="/opt/Carme/Carme-Vendors/mambaforge/envs/carme-backend/bin"

  ################################### grouping ############################################
  { 
 
  log "start slurmctld prolog"

  # set PATH ------------------------------------------------------------------------------
  if [[ -d ${PATH_CARME_BACKEND_BIN} ]]; then
    export PATH=${PATH_CARME_BACKEND_BIN}:${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  else
    die "[prolog.sh]: ${PATH_CARME_BACKEND_BIN} not found." 
  fi

  # config variables ----------------------------------------------------------------------
  if [[ -f ${FILE_BACKEND_CONFIG} ]]; then

    CARME_BACKEND_SERVER=$(get_variable CARME_BACKEND_SERVER ${FILE_BACKEND_CONFIG})
    CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${FILE_BACKEND_CONFIG})
    CARME_PATH_SCRIPTS=$(get_variable CARME_PATH_SCRIPTS ${FILE_BACKEND_CONFIG})

    [[ -z ${CARME_BACKEND_SERVER} ]] && die "[prolog.sh]: CARME_BACKEND_SERVER not set."
    [[ -z ${CARME_BACKEND_PORT} ]] && die "[prolog.sh]: CARME_BACKEND_PORT not set."
    [[ -z ${CARME_PATH_SCRIPTS} ]] && die "[prolog.sh]: CARME_PATH_SCRIPTS not set."

  else
    die "[prolog.sh]: ${FILE_BACKEND_CONFIG} not found."
  fi
 
  # check commands ------------------------------------------------------------------------
  check_command grep
  check_command python3

  # call notify_job_prolog ----------------------------------------------------------------
  log "run ${CARME_PATH_SCRIPTS}/backend/notify_job_prolog.py"
  #if ! python3 "${CARME_SCRIPTS_PATH}"/backend/notify_job_prolog.py "${SLURM_JOB_ID}" "${SLURM_JOB_USER}" "${CARME_BACKEND_SERVER}" "${CARME_BACKEND_PORT}"
  #then
  #  die "${CARME_SCRIPTS_PATH}/backend/notify_job_prolog.py failed"
  #fi

  log "finished slurmctld prolog"

} > "${FILE_SLURMCTLD_PROLOG}" 2>&1
  ##########################################################################################
fi

exit 0
