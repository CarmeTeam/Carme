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

export TMPDIR=$HOME/carme_tmp
export TMP=$HOME/carme_tmp
export TEMP=$HOME/carme_tmp

# wait until master is up and running
sleep 10
source ${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/bash_${SLURM_JOB_ID}

# start ssh server if a job has more than one node or mor than one GPU
if [[ "${SLURM_JOB_NUM_NODES}" -gt "1" || "${#GPUS}" -gt "1" ]]; then
		SSHDIR=${HOME}"/.local/share/carme/tmp-files-"${SLURM_JOB_ID}"/ssh_"${SLURM_JOB_ID}
		echo "WORKER: starting SSHD on WORKER" $(hostname)
		/usr/sbin/sshd -p 2222 -D -h ${SSHDIR}/server_key_${SLURM_JOB_ID} -E ${SSHDIR}/sshd_log_${SLURM_JOB_ID} -f ${SSHDIR}/sshd_config_${SLURM_JOB_ID} &
fi

