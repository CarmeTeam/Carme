#!/bin/bash

#
# notify carme about the job prolog
#

export PATH=${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# define function to get variables from CarmeConfig --------------------------------------------------------------------------------
function get_variable () {
  variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
  variable_value=${variable_value%#*}
  variable_value=${variable_value%#*}
  variable_value=$(echo "$variable_value" | tr -d '"')
  echo $variable_value
}

# source needed variables
CONFIG_FILE="/opt/Carme/CarmeConfig.backend"
CARME_BACKEND_SERVER=$(get_variable CARME_BACKEND_SERVER ${CONFIG_FILE})
CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${CONFIG_FILE})
CARME_SCRIPTS_PATH=$(get_variable CARME_SCRIPTS_PATH ${CONFIG_FILE})
# ----------------------------------------------------------------------------------------------------------------------------------


# call notify_job_prolog -----------------------------------------------------------------------------------------------------------
python3 ${CARME_SCRIPTS_PATH}/backend/notify_job_prolog.py ${SLURM_JOB_ID} ${SLURM_JOB_USER} ${CARME_BACKEND_SERVER} ${CARME_BACKEND_PORT}
# ----------------------------------------------------------------------------------------------------------------------------------

exit 0
