#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme                                         
#-----------------------------------------------------------------------------------------------------------------------------------
# submitJob.sh - submit a slurm job                                                                                                                                                                     
# 
# usage: submitJob CARME_SLURM_SCRIPTS_PATH $DBJOBID $IMAGE $MOUNTS $NUM_GPUS_PER_NODE $MEM $NTASKS $WORKER_NODES JOBID IMAGE MOUNTS PARTITION NUM_GPUS_PER_NODE NUM_NODES JOB_NAME
#                                               
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#                                                   
# Copyright 2019 by Fraunhofer ITWM                 
# License: http://open-carme.org/LICENSE.md         
# Contact: info@open-carme.org                      
#-----------------------------------------------------------------------------------------------------------------------------------

function get_variable () {
  variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
		variable_value=${variable_value%#*}
		variable_value=$(echo "$variable_value" | tr -d '"')
		variable_value="${variable_value}"
  echo $variable_value
}

#-----------------------------------------------------------------------------------------------------------------------------------

CARME_SCRIPTS_PATH=$1
CONFIG_FILE="${CARME_SCRIPTS_PATH}/../InsideContainer/CarmeConfig.container"

LOGDIR="/home/$USER/.job-log-dir"
if [ ! -d $LOGDIR ]; then
    mkdir $LOGDIR
fi

DBJOBID=$2
IMAGE=$3
MOUNTS=$4
PARTITION=$5
NUM_GPUS_PER_NODE=$6
NUM_NODES=$7
JOB_NAME=$8
CARME_SCRIPT_PATH=$9
GPU_TYPE=${10}

COUNTER=1
COUNTERLIMIT=1

echo "startJob" $JOB_NAME $NUM_NODES

#using tasks to get slurm to schedule not more jobs than the num of GPUs

GPU_DEFAULTS=$(get_variable CARME_GPU_DEFAULTS ${CONFIG_FILE})
PARAMETERS=(${GPU_DEFAULTS// / })
for PARAMS in ${PARAMETERS[@]};do
  if [[ "$PARAMS" =~ "${GPU_TYPE}" ]]; then
    VALUES=(${PARAMS//:/ })
    CORES_PER_GPU="${VALUES[1]}"
    MEM_PER_GPU="${VALUES[2]}"
  fi
done

if [[ -z ${CORES_PER_GPU} ]];then
  echo "ERROR: CPUs not set!"
  exit 137
fi

if [[ -z ${MEM_PER_GPU} ]];then
  echo "ERROR: Memory not set!"
  exit 137
fi

NTASKS=$((CORES_PER_GPU*NUM_GPUS_PER_NODE))

WORKER_NODES=$((NUM_NODES-1))

MEM=$((MEM_PER_GPU*NUM_GPUS_PER_NODE))

if [[ "${GPU_TYPE}" == "default" ]];then
  SBATCH_PARAMETERS="--partition=${PARTITION} --job-name=${JOB_NAME} --nodes=${NUM_NODES} --ntasks-per-node=${NTASKS} --mem=${MEM}G --gres=gpu:${NUM_GPUS_PER_NODE} --gres-flags=enforce-binding -o ${LOGDIR}/%j-${JOB_NAME}.out -e ${LOGDIR}/%j-${JOB_NAME}.err"
else
		SBATCH_PARAMETERS="--partition=${PARTITION} --job-name=${JOB_NAME} --nodes=${NUM_NODES} --ntasks-per-node=${NTASKS} --mem=${MEM}G --gres=gpu:${GPU_TYPE}:${NUM_GPUS_PER_NODE} --gres-flags=enforce-binding -o ${LOGDIR}/%j-${JOB_NAME}.out -e ${LOGDIR}/%j-${JOB_NAME}.err"
fi

while [ $COUNTER -le $COUNTERLIMIT ]
do
  if [ "$NUM_NODES" != 1 ]; then
		  sbatch ${SBATCH_PARAMETERS} ${CARME_SCRIPTS_PATH}/slurm-parallel.sh ${DBJOBID} ${IMAGE} ${MOUNTS} ${NUM_GPUS_PER_NODE} ${MEM} ${CARME_SCRIPT_PATH} ${NTASKS $WORKER_NODES} ${GPU_TYPE}
  else
				sbatch ${SBATCH_PARAMETERS} ${CARME_SCRIPTS_PATH}/slurm.sh ${DBJOBID} ${IMAGE} ${MOUNTS} ${NUM_GPUS_PER_NODE} ${MEM} ${CARME_SCRIPT_PATH} ${GPU_TYPE}
		fi
  ((COUNTER++))
done

#--time=1440 # = 1 day
#--begin=now+180
printf "all jobs submitted\n"
