#!/bin/sh

#
# notify carme about the job epilog
#

# define function to get variables from CarmeConfig --------------------------------------------------------------------------------
function get_variable () {
  variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
  variable_value=${variable_value%#*}
  variable_value=${variable_value%#*}
  variable_value=$(echo "$variable_value" | tr -d '"')
  echo $variable_value
}

# source needed variables
CONFIG_FILE="/opt/Carme/CarmeConfig"
CARME_BACKEND_SERVER=$(get_variable CARME_BACKEND_SERVER ${CONFIG_FILE})
CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${CONFIG_FILE})
# ----------------------------------------------------------------------------------------------------------------------------------


# call notify_job_epilog -----------------------------------------------------------------------------------------------------------
python notify_job_epilog.py SLURM_JOB_ID SLURM_JOB_USER CARME_BACKEND_SERVER CARME_BACKEND_PORT
# ----------------------------------------------------------------------------------------------------------------------------------
