#!/bin/sh
#-----------------------------------------------------------------------------------------------------------------------------------
# This script will kill any user processes on a node when the last
# SLURM job there ends. For example, if a user directly logs into
# an allocated node SLURM will not kill that process without this
# script being executed as an epilog.
#-----------------------------------------------------------------------------------------------------------------------------------

# SLURM_BIN can be used for testing with private version of SLURM ------------------------------------------------------------------
#SLURM_BIN="/usr/bin/"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if something has to be done ------------------------------------------------------------------------------------------------
if [ x$SLURM_JOB_USER == "x" ] ; then
  exit 0
fi

if [ x$SLURM_JOB_ID == "x" ] ; then
  exit 0
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# Don't try to kill user root or system daemon jobs --------------------------------------------------------------------------------
if [ -z "$SYS_UID_MAX" ]; then
  SYS_UID_MAX=999
fi

if [ $SLURM_JOB_UID -lt $SYS_UID_MAX ] ; then
  exit 0
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# determine slurm jobs of this user ------------------------------------------------------------------------------------------------
job_list=`${SLURM_BIN}squeue --noheader --format=%i --user=$SLURM_JOB_USER --node=localhost`

for job_id in $job_list
do
  if [ $job_id -ne $SLURM_JOB_ID ] ; then
    exit 0
  fi
done
#-----------------------------------------------------------------------------------------------------------------------------------


# purge all remaining processes of this user ---------------------------------------------------------------------------------------

# write message to /var/log/messages
logger "slurm epilog script: job $SLURM_JOB_ID ($SLURM_JOB_USER) kill all remaining processes"

# try to kill remaining processes with SIGTERM
pkill -TERM -U $SLURM_JOB_USER

# check if job is still running
if [ $? -eq 0 ]; then
  sleep 30s
  pkill -KILL -U $SLURM_JOB_USER
  logger "slurm epilog script: job $SLURM_JOB_ID ($SLURM_JOB_USER) had to be killed using SIGKILL - check what is going on"
fi

# delete .bash_carme_$SLURM_JOB_ID
rm /home/${SLURM_JOB_USER}/.carme/.bash_carme_${SLURM_JOB_ID}

# delete local scratch folder
rm -r /scratch_local/${SLURM_JOB_ID}

# remove job tensorboard folder
rm -r /home/${SLURM_JOB_USER}/tensorboard/tensorboard_${SLURM_JOB_ID}

# remove job ssh stuff
rm /home/${SLURM_JOB_USER}/.tmp_ssh/server_key_${SLURM_JOB_ID}
rm /home/${SLURM_JOB_USER}/.tmp_ssh/client_key_${SLURM_JOB_ID}
rm /home/${SLURM_JOB_USER}/.ssh/id_rsa_${SLURM_JOB_ID}
OLD_KEY=$(cat /home/${SLURM_JOB_USER}/.tmp_ssh/client_key_${SLURM_JOB_ID}.pub)
grep -v "${OLD_KEY}" /home/${SLURM_JOB_USER}/.ssh/authorized_keys > /home/${SLURM_JOB_USER}/.ssh/authorized_keys_temp
mv /home/${SLURM_JOB_USER}/.ssh/authorized_keys_temp /home/${SLURM_JOB_USER}/.ssh/authorized_keys
USER_GROUP=$(id -gn ${SLURM_JOB_USER})
chown ${SLURM_JOB_USER}:${USER_GROUP} /home/${SLURM_JOB_USER}/.ssh/authorized_keys
rm /home/${SLURM_JOB_USER}/.tmp_ssh/client_key_${SLURM_JOB_ID}.pub
rm /home/${SLURM_JOB_USER}/.tmp_ssh/server_key_${SLURM_JOB_ID}.pub
rm /home/${SLURM_JOB_USER}/.tmp_ssh/sshd_config_${SLURM_JOB_ID}
rm /home/${SLURM_JOB_USER}/.tmp_ssh/sshd_log_${SLURM_JOB_ID}

exit 0

