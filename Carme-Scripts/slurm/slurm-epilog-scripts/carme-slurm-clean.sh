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

# check if something has to be done ------------------------------------------------------------------------------------------------
if [[ -z "${SLURM_JOB_USER}" || -z "${SLURM_JOB_ID}" ]]; then
  exit 0
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# Don't try to kill user root or system daemon jobs --------------------------------------------------------------------------------
if [ -z "$SYS_UID_MAX" ]; then
  SYS_UID_MAX=999
fi

if [ $SLURM_JOB_UID -lt $SYS_UID_MAX ]; then
  exit 0
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# delte CARME specific job folders -------------------------------------------------------------------------------------------------
# delete local scratch folder ------------------------------------------------------------------------------------------------------
if [[ -d "/scratch_local/${SLURM_JOB_ID}" ]];then
  rm -r /scratch_local/${SLURM_JOB_ID} 
fi


# remove stuff in ${HOME} ----------------------------------------------------------------------------------------------------------
MASTER_NODE=$(scontrol show job ${SLURM_JOB_ID} | grep BatchHost | cut -d "=" -f 2 | cut -d/ -f1)
USER_HOME=$(getent passwd ${SLURM_JOB_USER} | cut -d: -f6)

if [[ "$(hostname)" == "${MASTER_NODE}" ]];then
  # remove job specific stuff
  if [[ -d "${USER_HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}" ]];then
    rm -r ${USER_HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}
  fi

  # remove job tensorboard folder
  if [[ -d "${USER_HOME}/tensorboard/tensorboard_${SLURM_JOB_ID}" ]];then
    rm -r ${USER_HOME}/tensorboard/tensorboard_${SLURM_JOB_ID}
  fi

  # remove job ssh stuff
  if [[ -f "${USER_HOME}/.ssh/id_rsa_${SLURM_JOB_ID}" ]];then
    rm ${USER_HOME}/.ssh/id_rsa_${SLURM_JOB_ID}
  fi
fi
#-----------------------------------------------------------------------------------------------------------------------------------

exit 0

