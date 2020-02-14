#!/bin/bash
# a simple bash script to start a singularity image
#
# usage: slurm JOBID IMAGE MOUNTS NUM_GPUS_PER_NODE Mem_limits
#
# @ Dr. Dominik Straßel, Janis Keuper 2018
#-----------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------------------
cd ${HOME}
#-----------------------------------------------------------------------------------------------------------------------------------

DBJOBID=$1
IMAGE=$2
mountstr=$3  
GPUS=$4
MEM=$5
CARME_SCRIPT_PATH=$6
GPU_TYPE=$7

#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container
CONFIG_FILE="${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container"
if [ -f ${CONFIG_FILE} ];then
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=$(echo "$variable_value" | tr -d '"')
    echo $variable_value
  }
else
  echo "${CONFIG_FILE} not found!"
  exit 137
fi

CARME_GATEWAY=$(get_variable CARME_GATEWAY ${CONFIG_FILE})
CARME_BACKEND_SERVER=$(get_variable CARME_BACKEND_SERVER ${CONFIG_FILE})
CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${CONFIG_FILE})
CARME_BUILDNODE_1_IP=$(get_variable CARME_BUILDNODE_1_IP ${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

MOUNTS=${mountstr//[_]/ }

IPADDR=$(ip route get ${CARME_GATEWAY} | head -1 | awk '{print $5}' | cut -d/ -f1)
if [[ -z ${IPADDR} ]];then
  echo "ERROR: IP not set!"
		exit 137
fi

#dummy valuse
NB_PORT=0
TB_PORT=0

echo "WORKER Parameters:"
echo "                 - IP: ${IPADDR}"
echo "                 - Backend-Server: ${CARME_BACKEND_SERVER}:${CARME_BACKEND_PORT}"
echo "                 - Image: ${IMAGE}"
echo ""

GPU_DEVICES=${CUDA_VISIBLE_DEVICES}
if [[ -z "${GPU_DEVICES}" ]];then
  echo "ERROR: WORKER: available GPUs not set!"
  echo "ERROR: WORKER: no free GPUs on node. Job stops now!"
  echo "ERROR: please contact your admin."
  exit 137
fi

echo "WORKER GPUS: " ${IPADDR} ${GPUS} ${GPU_DEVICES}
if [[ "${GPU_TYPE}" == "default" ]];then
  echo "WORKER GPUS: #(GPUS): ${GPUS}, GPU-Devices: ${GPU_DEVICES}, GPU type not specified"
else
		echo "WORKER GPUS: #(GPUs): ${GPUS}, GPU-Devices: ${GPU_DEVICES}, GPU type: ${GPU_TYPE}"
fi
echo ""

#crate SSD scratch folder------------------------------------
if [[ -d /scratch_local ]];then
  mkdir -p /scratch_local/${SLURM_JOB_ID}
  echo "/home/SSD is a fast local scratch storage. WARMING: everything will be deleted at the end of this job!" > /scratch_local/${SLURM_JOB_ID}/readme.md
else
	 echo "ERROR: WORKER: cannot create folder on local SSD"
		echo "               SSD parent folder not found"
fi
#-------------------------------------------------------------                        

#start singularity ------------------------------------
if [ ${IPADDR} != "${CARME_BUILDNODE_1_IP}" ];then
  newpid singularity exec -B /opt/Carme/Carme-Scripts/InsideContainer/base_bashrc.sh:/etc/bash.bashrc -B /etc/libibverbs.d ${MOUNTS} -B /scratch_local/${SLURM_JOB_ID}:/home/SSD ${IMAGE} /bin/bash /home/.CarmeScripts/start_worker.sh ${IPADDR} ${NB_PORT} ${TB_PORT} ${USER} ${HASH} ${GPU_DEVICES} ${MEM}
else
  newpid singularity exec -B /opt/Carme/Carme-Scripts/InsideContainer/base_bashrc.sh:/etc/bash.bashrc -B /etc/libibverbs.d ${MOUNTS} ${IMAGE} /bin/bash /home/.CarmeScripts/start_worker.sh ${IPADDR} ${NB_PORT} ${TB_PORT} ${TA_PORT} ${USER} ${HASH} ${GPU_DEVICES} ${MEM} ${GPUS}
fi
#------------------------------------------------------

