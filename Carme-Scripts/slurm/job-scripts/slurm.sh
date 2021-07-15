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



# define variables -----------------------------------------------------------------------------------------------------------------

#SINGULARITY_BIN="/usr/bin/singularity"
#NOTE: This variable can be used to define a local singularity version that is not part of "${PATH}". If the variable is not used
#      it is assumed that "singularity" is available via "${PATH}" and respective checks are preformed later in this script.
#NOTE: If set it has to be the FULL PATH to the singularity binary including the binary itself.

SINGULARITY_FLAGS="--pid --nv"
# Here we define the flags that singularity should use (these flags are used fo all images)
#  - "--pid": start everything inside the container within a new namespace
#  - "--nv": enabling NVIDIA support using drivers from the host system
#NOTE: If you modify these flags make sure that the flags work with your singularity version.

#-----------------------------------------------------------------------------------------------------------------------------------


# define function to print time and date -------------------------------------------------------------------------------------------
function currenttime () {
  date +"[%F %T.%3N]"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "$(currenttime) $(hostname -s): ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function that checks if a command is available or not ---------------------------------------------------------------------
function check_command () {
  if ! command -v "${1}" >/dev/null 2>&1 ;then
    die "command '${1}' not found"
  fi
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function for regular node output ------------------------------------------------------------------------------------------
function log () {
  echo "$(currenttime) $(hostname -s): ${1}"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# external variables ---------------------------------------------------------------------------------------------------------------
IMAGE=${1}
[[ -z ${IMAGE} ]] && die "no singularity image defined"

FLAGS=${2}
[[ -z ${FLAGS} ]] && die "no flags defined"
FLAGS=${FLAGS//[_]/ }
#-----------------------------------------------------------------------------------------------------------------------------------


# check if this is not the first slurm task on a node ------------------------------------------------------------------------------
[[ "${SLURM_LOCALID}" != "0" ]] && exit 0
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command squeue

if [[ -n "${SLURM_JOB_GPUS}" ]];then
  check_command nvidia-smi
fi

check_command hostname

if [[ -n "${SINGULARITY_BIN}" ]];then
  [[ ! -f "${SINGULARITY_BIN}" && ! -x "${SINGULARITY_BIN}" ]] && die "command ${SINGULARITY_BIN} not found"
else
  SINGULARITY_BIN="singularity"
  check_command "${SINGULARITY_BIN}"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


#source job bashrc -----------------------------------------------------------------------------------------------------------------
source "${HOME}/.local/share/carme/job/${SLURM_JOB_ID}/bashrc" || die "cannot source job bashrc"
#-----------------------------------------------------------------------------------------------------------------------------------


#source job ports ------------------------------------------------------------------------------------------------------------------
if [[ "$(hostname -s)" == "${CARME_MASTER}" || ("${CARME_START_SSHD}" == "always" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1")) ]];then
  source "${CARME_JOBDIR}/ports/$(hostname -s)" || die "cannot source job ports"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# things that should only be done on master node -----------------------------------------------------------------------------------
if [[ "$(hostname -s)" == "${CARME_MASTER}" ]];then

  # check if hash is set
  [[ -z ${CARME_HASH} ]] && die "hash not set"


  # check if IP is set
  [[ -z ${CARME_MASTER_IP} ]] && die "master ip not set"

  # check if hash is set
  [[ -z ${CARME_HASH} ]] && die "hash not set"

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


  # add job to global job-log-file
  [[ -z ${CARME_LOGDIR} ]] && die "CARME_LOGDIR not set"
  echo -e "${SLURM_JOB_ID}\t${SLURM_JOB_NAME}\t$(hostname -s)\t${CARME_NODES}\t${STARTTIME}\t${ENDTIME}" >> "${CARME_LOGDIR}/job-log.dat"
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

  log "create ssh env file ${CARME_SSHDIR}/envs/$(hostname -s)"
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
export GPU_DEVICE_ORDINAL=\"${GPU_DEVICE_ORDINAL}\"" > "${CARME_SSHDIR}/envs/$(hostname -s)"

fi
#-----------------------------------------------------------------------------------------------------------------------------------


#change dir to user home -----------------------------------------------------------------------------------------------------------
cd "${HOME}" || die "cannot change directory to ${HOME}"
#-----------------------------------------------------------------------------------------------------------------------------------


#start singularity -----------------------------------------------------------------------------------------------------------------
export XDG_RUNTIME_DIR=""


# paths outside and inside the container
SCRIPTS_PATH_HOST="/opt/Carme/Carme-Scripts/InsideContainer"
SCRIPTS_PATH_CONTAINER="/home/.CarmeScripts"


# define singularity default binds
DEFAULT_BINDS="-B ${SCRIPTS_PATH_HOST}/base_bashrc.sh:/etc/bash.bashrc -B ${SCRIPTS_PATH_HOST}:${SCRIPTS_PATH_CONTAINER}"


# add image flags from the DB
BINDS="${DEFAULT_BINDS} ${FLAGS}"


# check if the local ssd variable is set and if the respective path on the ssd exists and if yes add to singularity binds
if [[ -n ${CARME_LOCAL_SSD_PATH} && -d "${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}" ]];then
  log "using local SSD"
  BINDS="${BINDS} -B ${CARME_LOCAL_SSD_PATH}/${SLURM_JOB_ID}:/home/SSD"
fi


[[ -z ${CARME_TMPDIR} ]] && die "CARME_TMPDIR not set"
if [[ -d "${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname -s)" ]];then
  log "using tmp dir ${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname -s)"
  BINDS="${BINDS} -B ${CARME_TMPDIR}/carme-job-${SLURM_JOB_ID}-$(hostname -s):/tmp"
else
  die "no tmp directory found"
fi


# put the singularity start command together
read -r -a SINGULARITY_START <<< "${SINGULARITY_BIN} exec ${SINGULARITY_FLAGS} ${BINDS} ${IMAGE} /bin/bash /home/.CarmeScripts/start_apps.sh"


log "start container"
log "image: ${IMAGE}"
log "image flags: ${SINGULARITY_FLAGS} ${BINDS}"

TZ=$(cat /etc/timezone) "${SINGULARITY_START[@]}"
#-----------------------------------------------------------------------------------------------------------------------------------
