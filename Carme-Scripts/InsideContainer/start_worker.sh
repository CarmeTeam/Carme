#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Default container startup script
#
# * starts jupyter end tensorboard
# * set env
# 
#-----------------------------------------------------------------------------------------------------------------------------------

IPADDR=$1
NB_PORT=$2
TB_PORT=$3
USER=$4
HASH=$5
GPUS=$6
MEM=$7

#-----------------------------------------------------------------------------------------------------------------------------------

MEM_LIMIT=$(( MEM * 1024 *1024 ))
echo "WORKER: Memory Limit ${MEM_LIMIT}KB"
echo ""

# wait until master is up and running ----------------------------------------------------------------------------------------------
COUNTER=0
while true; do
  if [ "${COUNTER}" -eq 6 ];then
    echo "ERROR: Tried for one minute to source ${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/bash_${SLURM_JOB_ID}"
    echo "       but could not find the file. Check if the file system is alright."
    exit 137
  fi

  if [[ -f  "${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/bash_${SLURM_JOB_ID}" ]];then
    source ${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/bash_${SLURM_JOB_ID}
    break
  else
    sleep 10
    ((COUNTER++))
  fi
done
#-----------------------------------------------------------------------------------------------------------------------------------

# start ssh server if a job has more than one node or mor than one GPU -------------------------------------------------------------
if [[ "${SLURM_JOB_NUM_NODES}" -gt "1" || "${#GPUS}" -gt "1" ]]; then

  # find new free sshd port
  NEW_SSHD_PORT=""
  BASE_PORT="2222"
  FINAL_PORT="2300"

  for ((i=${BASE_PORT};i<=${FINAL_PORT};i++)); do
    LISTEN=$(ss -tln -4 | grep ${i})

    if [ -z "${LISTEN}" ];then
      NEW_SSHD_PORT=${i}
      break
    fi

    if [[ "$i" -eq "${FINAL_PORT}" && ! -z "${LISTEN}" ]];then
      echo "ERROR: No free SSHD port found!"
      exit 137
    fi
  done

		SSHDIR=${HOME}"/.local/share/carme/tmp-files-"${SLURM_JOB_ID}"/ssh_"${SLURM_JOB_ID}

  echo "Host $(hostname)
  HostName $(hostname)
  User ${USER}
  Port ${NEW_SSHD_PORT}
  IdentityFile ${HOME}/.ssh/id_rsa_${SLURM_JOB_ID}
" >> ${SSHDIR}/ssh_config_${SLURM_JOB_ID}

		echo "WORKER: starting SSHD on WORKER" $(hostname)
		/usr/sbin/sshd -p ${NEW_SSHD_PORT} -D -h ${SSHDIR}/server_key_${SLURM_JOB_ID} -E ${SSHDIR}/sshd_log_${SLURM_JOB_ID} -f ${SSHDIR}/sshd_config_${SLURM_JOB_ID} &
fi
#-----------------------------------------------------------------------------------------------------------------------------------

# wait until the job is done -------------------------------------------------------------------------------------------------------
wait
#-----------------------------------------------------------------------------------------------------------------------------------

