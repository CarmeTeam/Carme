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


#-----------------------------------------------------------------------------------------------------------------------------------
# remove stuff in ${HOME}

USER_HOME=$(getent passwd ${SLURM_JOB_USER} | cut -d: -f6)

# delete .bash_carme_$SLURM_JOB_ID
rm ${USER_HOME}/.carme/.bash_carme_${SLURM_JOB_ID}

# delete local scratch folder
rm -r /scratch_local/${SLURM_JOB_ID}

# remove job tensorboard folder
rm -r ${USER_HOME}/tensorboard/tensorboard_${SLURM_JOB_ID}

# remove theia tmp folder
rm -r ${USER_HOME}/carme_tmp/${SLURM_JOB_ID}_job_tmp

# remove job ssh stuff
rm ${USER_HOME}/.tmp_ssh/server_key_${SLURM_JOB_ID}
rm ${USER_HOME}/.tmp_ssh/client_key_${SLURM_JOB_ID}
rm ${USER_HOME}/.ssh/id_rsa_${SLURM_JOB_ID}

OLD_KEY=$(cat ${USER_HOME}/.tmp_ssh/client_key_${SLURM_JOB_ID}.pub)
set +e
grep -v "${OLD_KEY}" ${USER_HOME}/.ssh/authorized_keys > ${USER_HOME}/.ssh/authorized_keys_temp
GREP_STATE=$?
set -e

if [ ${GREP_STATE} -eq 0 ]; then
  mv ${USER_HOME}/.ssh/authorized_keys_temp ${USER_HOME}/.ssh/authorized_keys
else
  rm ${USER_HOME}/.ssh/authorized_keys
  rm ${USER_HOME}/.ssh/authorized_keys_temp
  touch ${USER_HOME}/.ssh/authorized_keys
fi

USER_GROUP=$(id -gn ${SLURM_JOB_USER})
chown ${SLURM_JOB_USER}:${USER_GROUP} ${USER_HOME}/.ssh/authorized_keys

rm ${USER_HOME}/.tmp_ssh/client_key_${SLURM_JOB_ID}.pub
rm ${USER_HOME}/.tmp_ssh/server_key_${SLURM_JOB_ID}.pub
rm ${USER_HOME}/.tmp_ssh/sshd_config_${SLURM_JOB_ID}
rm ${USER_HOME}/.tmp_ssh/sshd_log_${SLURM_JOB_ID}
#-----------------------------------------------------------------------------------------------------------------------------------

exit 0

