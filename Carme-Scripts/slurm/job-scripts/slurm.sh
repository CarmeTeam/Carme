#!/bin/bash
# ----------------------------------------------------------------------------------------------------------------------------------
# Carme
# ----------------------------------------------------------------------------------------------------------------------------------
# slurm.sh
#
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
# * Carme/Carme-Doc/DevelDoc/BackendDocu.md
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# Contact: info@open-carme.org
# ----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to print time and date -------------------------------------------------------------------------------------------
function currenttime () {
  date +"[%F %T.%3N]"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "$(currenttime) $(hostname): ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# external variables ---------------------------------------------------------------------------------------------------------------
IMAGE=$1
[[ -z ${IMAGE} ]] && die "no singularity image defined"

MOUNTSTR=$2
[[ -z ${MOUNTSTR} ]] && die "no mounts defined"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if this is not the first slurm task on a node ------------------------------------------------------------------------------
[[ "${SLURM_LOCALID}" != "0" ]] && exit 0
#-----------------------------------------------------------------------------------------------------------------------------------


# define function for regular node output ------------------------------------------------------------------------------------------
function log () {
  echo "$(currenttime) $(hostname): ${1}"
}
#-----------------------------------------------------------------------------------------------------------------------------------


#source job bashrc -----------------------------------------------------------------------------------------------------------------
source "${HOME}/.local/share/carme/job/${SLURM_JOB_ID}/bashrc" || die "cannot source job bashrc"
#-----------------------------------------------------------------------------------------------------------------------------------


#source job ports ------------------------------------------------------------------------------------------------------------------
if [[ "$(hostname)" == "${CARME_MASTER}" || ("${CARME_START_SSHD}" == "always" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1")) ]];then
  source "${CARME_JOBDIR}/ports/$(hostname)" || die "cannot source job ports"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# things that should only be done on master node -----------------------------------------------------------------------------------
if [[ "$(hostname)" == "${CARME_MASTER}" ]];then

  # check if hash is set
  [[ -z ${CARME_HASH} ]] && die "hash not set"


  # check if IP is set
  [[ -z ${CARME_MASTER_IP} ]] && die "master ip not set"


  # get start- and estimated end-time
  STARTTIME=$(squeue -h -j "${SLURM_JOB_ID}" -o "%.20S")
  ENDTIME=$(squeue -h -j "${SLURM_JOB_ID}" -o "%.20e")


  # write debug to logfile
  log "carme version: ${CARME_VERSION}"
  log "job id: ${SLURM_JOB_ID}"
  log "job name: ${SLURM_JOB_NAME}"
  log "nodelist: ${CARME_NODES}"
  log "start-time: ${STARTTIME}"
  log "end-time:   ${ENDTIME} (estimated)"
  log "hash: ${CARME_HASH}"
  log "master ip: ${CARME_MASTER_IP}"
  log "image: ${IMAGE}"
  log "mount points: ${MOUNTSTR}"


  # add job to global job-log-file
  [[ -z ${CARME_LOGDIR} ]] && die "CARME_LOGDIR not set"
  echo -e "${SLURM_JOB_ID}\t${SLURM_JOB_NAME}\t$(hostname)\t${CARME_NODES}\t${STARTTIME}\t${ENDTIME}" >> "${CARME_LOGDIR}/job-log.dat"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check GPU stuff if job has gpus---------------------------------------------------------------------------------------------------
if [[ -n "${SLURM_JOB_GPUS}" ]];then
  log "number of gpus: $(echo "${SLURM_JOB_GPUS}" | tr ',' '\n' | wc -l)"
  log "gpu devices: ${SLURM_JOB_GPUS}"

  mapfile -t GPU_TYPES < <(nvidia-smi --query-gpu=index,gpu_name --format=csv,noheader | awk -F', ' '{ print "GPU"$1": " $2 }')

  for GPU_TYPE in "${GPU_TYPES[@]}"; do
    log "${GPU_TYPE}"
  done
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# write node specific env variables to file so that they can be made available via ssh ---------------------------------------------
if [[ "${CARME_START_SSHD}" == "always" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1") ]];then

  [[ -z ${CARME_SSHDIR} ]] && die "CARME_SSHDIR not set"

  log "create ssh env file ${CARME_SSHDIR}/envs/$(hostname)"
  echo "#!/bin/bash
export SLURM_CHECKPOINT_IMAGE_DIR=\"${SLURM_CHECKPOINT_IMAGE_DIR}\"
export SLURM_CLUSTER_NAME=\"${SLURM_CLUSTER_NAME}\"
export SLURM_CPUS_ON_NODE=\"${SLURM_CPUS_ON_NODE}\"
export SLURM_CPUS_PER_TASK=\"${SLURM_CPUS_PER_TASK}\"
export SLURM_DISTRIBUTION=\"${SLURM_DISTRIBUTION}\"
export SLURMD_NODENAME=\"${SLURMD_NODENAME}\"
export SLURM_GTIDS=\"${SLURM_GTIDS}\"
export SLURM_JOB_ACCOUNT=\"${SLURM_JOB_ACCOUNT}\"
export SLURM_JOB_CPUS_PER_NODE=\"${SLURM_JOB_CPUS_PER_NODE}\"
export SLURM_JOB_GID=\"${SLURM_JOB_GID}\"
export SLURM_JOB_GPUS=\"${SLURM_JOB_GPUS}\"
export SLURM_JOB_ID=\"${SLURM_JOB_ID}\"
export SLURM_JOBID=\"${SLURM_JOBID}\"
export SLURM_JOB_NAME=\"${SLURM_JOB_NAME}\"
export SLURM_JOB_NODELIST=\"${SLURM_JOB_NODELIST}\"
export SLURM_JOB_NUM_NODES=\"${SLURM_JOB_NUM_NODES}\"
export SLURM_JOB_PARTITION=\"${SLURM_JOB_PARTITION}\"
export SLURM_JOB_QOS=\"${SLURM_JOB_QOS}\"
export SLURM_JOB_UID=\"${SLURM_JOB_UID}\"
export SLURM_JOB_USER=\"${SLURM_JOB_USER}\"
export SLURM_LAUNCH_NODE_IPADDR=\"${SLURM_LAUNCH_NODE_IPADDR}\"
export SLURM_LOCALID=\"${SLURM_LOCALID}\"
export SLURM_MEM_PER_NODE=\"${SLURM_MEM_PER_NODE}\"
export SLURM_NNODES=\"${SLURM_NNODES}\"
export SLURM_NODEID=\"${SLURM_NODEID}\"
export SLURM_NODELIST=\"${SLURM_NODELIST}\"
export SLURM_NPROCS=\"${SLURM_NPROCS}\"
export SLURM_NTASKS=\"${SLURM_NTASKS}\"
export SLURM_NTASKS_PER_NODE=\"${SLURM_NTASKS_PER_NODE}\"
export SLURM_PRIO_PROCESS=\"${SLURM_PRIO_PROCESS}\"
export SLURM_PROCID=\"${SLURM_PROCID}\"
export SLURM_SRUN_COMM_HOST=\"${SLURM_SRUN_COMM_HOST}\"
export SLURM_SRUN_COMM_PORT=\"${SLURM_SRUN_COMM_PORT}\"
export SLURM_STEP_GPUS=\"${SLURM_STEP_GPUS}\"
export SLURM_STEP_ID=\"${SLURM_STEP_ID}\"
export SLURM_STEPID=\"${SLURM_STEPID}\"
export SLURM_STEP_LAUNCHER_PORT=\"${SLURM_STEP_LAUNCHER_PORT}\"
export SLURM_STEP_NODELIST=\"${SLURM_STEP_NODELIST}\"
export SLURM_STEP_NUM_NODES=\"${SLURM_STEP_NUM_NODES}\"
export SLURM_STEP_NUM_TASKS=\"${SLURM_STEP_NUM_TASKS}\"
export SLURM_STEP_TASKS_PER_NODE=\"${SLURM_STEP_TASKS_PER_NODE}\"
export SLURM_SUBMIT_DIR=\"${SLURM_SUBMIT_DIR}\"
export SLURM_SUBMIT_HOST=\"${SLURM_SUBMIT_HOST}\"
export SLURM_TASK_PID=\"${SLURM_TASK_PID}\"
export SLURM_TASKS_PER_NODE=\"${SLURM_TASKS_PER_NODE}\"
export SLURM_TOPOLOGY_ADDR=\"${SLURM_TOPOLOGY_ADDR}\"
export SLURM_TOPOLOGY_ADDR_PATTERN=\"${SLURM_TOPOLOGY_ADDR_PATTERN}\"
export SLURM_UMASK=\"${SLURM_UMASK}\"
export SLURM_WORKING_CLUSTER=\"${SLURM_WORKING_CLUSTER}\"
export CUDA_VISIBLE_DEVICES=\"${CUDA_VISIBLE_DEVICES}\"
export GPU_DEVICE_ORDINAL=\"${GPU_DEVICE_ORDINAL}\"" > "${CARME_SSHDIR}/envs/$(hostname)"

fi
#-----------------------------------------------------------------------------------------------------------------------------------


#change dir to user home -----------------------------------------------------------------------------------------------------------
cd "${HOME}" || die "cannot change directory to ${HOME}"
#-----------------------------------------------------------------------------------------------------------------------------------


#start singularity -----------------------------------------------------------------------------------------------------------------
export XDG_RUNTIME_DIR=""

# split predefined mounts (separated by space)
# NOTE: never double quote this variable!
MOUNTS=${MOUNTSTR//[_]/ }

[[ -z ${CARME_LOCAL_SSD_PATH} ]] && die "CARME_LOCAL_SSD_PATH not set"
if [[ -d "${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}" ]];then
  log "using local SSD"
  MOUNTS="${MOUNTS} -B \"${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}:/home/SSD\""
fi


[[ -z ${CARME_TMPDIR} ]] && die "CARME_TMPDIR not set"
if [[ -d "${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname)" ]];then
  log "using tmp dir ${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname)"
  MOUNTS="${MOUNTS} -B \"${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname):/tmp\""
else
  die "no tmp directory found"
fi


# NOTE: never double quote this variable!
BINDS="-B /opt/Carme/Carme-Scripts/InsideContainer/base_bashrc.sh:/etc/bash.bashrc"


log "start container"
TZ=$(cat /etc/timezone) newpid singularity exec --nv ${BINDS} ${MOUNTS} "${IMAGE}" /bin/bash /home/.CarmeScripts/start_apps.sh
#-----------------------------------------------------------------------------------------------------------------------------------
