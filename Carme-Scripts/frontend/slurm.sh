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


# external variables ---------------------------------------------------------------------------------------------------------------
DBJOBID=$1
IMAGE=$2
mountstr=$3
GPUS=$4
MEM=$5
CARME_SCRIPT_PATH=$6
GPU_TYPE=$7
#-----------------------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container
CONFIG_FILE="${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container"
if [ -f ${CONFIG_FILE} ];then
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=${variable_value%#*}
    variable_value=${variable_value%#*}
    variable_value=$(echo "$variable_value" | tr -d '"')
    echo $variable_value
  }
else
  echo "${CONFIG_FILE} not found!"
  exit 137
fi

CARME_VERSION=$(get_variable CARME_VERSION ${CONFIG_FILE})
CARME_URL=$(get_variable CARME_URL ${CONFIG_FILE})
CARME_GATEWAY=$(get_variable CARME_GATEWAY ${CONFIG_FILE})
CARME_BACKEND_SERVER=$(get_variable CARME_BACKEND_SERVER ${CONFIG_FILE})
CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

echo "Carme Verison: ${CARME_VERSION}"
echo ""

NODELIST=$(scontrol show hostname ${SLURM_JOB_NODELIST})
echo "NODELIST: ${NODELIST}"
echo ""

STARTTIME=$(squeue -h -j ${SLURM_JOB_ID} -o "%.20S")
ENDTIME=$(squeue -h -j ${SLURM_JOB_ID} -o "%.20e")
echo "STARTTIME: ${STARTTIME}"
echo "ENDTIME: ${ENDTIME}"
echo ""

MOUNTS=${mountstr//[_]/ }   
export HASH=$(head /dev/urandom | tr -dc a-z0-9 | head -c 30) 
URL=${CARME_URL}/nb_${HASH}

IPADDR=$(ip route get ${CARME_GATEWAY} | head -1 | awk '{print $5}' | cut -d/ -f1)
if [[ -z ${IPADDR} ]];then
  echo "ERROR: IP not set!"
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------------------
#set variables and environment stuff -----------------------------------------------------------------------------------------------

echo "MASTER Parameters:"
echo "                 - IP: ${IPADDR}"
echo "                 - Backend-Server: ${CARME_BACKEND_SERVER}:${CARME_BACKEND_PORT}"
echo "                 - Image: ${IMAGE}"
echo ""

GPU_DEVICES=${CUDA_VISIBLE_DEVICES}
if [[ -z "${GPU_DEVICES}" ]];then
  echo "ERROR: MASTER: available GPUs not set!"
  echo "ERROR: MASTER: no free GPUs on node. Job stops!"
  echo "ERROR: MASTER: please contact your admin."
		echo ""
  exit 137
fi

if [[ "${GPU_TYPE}" == "default" ]];then
		echo "MASTER GPUS: #(GPUS): ${GPUS}, GPU-Devices: ${GPU_DEVICES}, GPU type not specified"
else
		echo "MASTER GPUS: #(GPUs): ${GPUS}, GPU-Devices: ${GPU_DEVICES}, GPU type: ${GPU_TYPE}"
fi
echo ""
#-----------------------------------------------------------------------------------------------------------------------------------


#compute ports: base port + first GPU id -------------------------------------------------------------------------------------------
offset=${GPU_DEVICES:0:1}
NB_PORT=$((8088 + offset))
TB_PORT=$((6668 + offset))
TA_PORT=$((TB_PORT + 10))
#-----------------------------------------------------------------------------------------------------------------------------------


#change dir to user home -----------------------------------------------------------------------------------------------------------
cd ${HOME}
#-----------------------------------------------------------------------------------------------------------------------------------


#set jupyter parameters and settings -----------------------------------------------------------------------------------------------
NBDIR="${HOME}/.jupyter" 
mkdir -p ${NBDIR}

STOREDIR=${HOME}"/.local/share/carme/tmp-files-"${SLURM_JOB_ID}
mkdir -p ${STOREDIR}

JUPYTER_CONFIG="jupyter_notebook_config-"${SLURM_JOB_ID}".py"
echo "c.NotebookApp.disable_check_xsrf = True" > ${STOREDIR}/${JUPYTER_CONFIG}
echo "c.NotebookApp.token = ''" >> ${STOREDIR}/${JUPYTER_CONFIG}
echo "c.NotebookApp.base_url = '/nb_${HASH}'" >> ${STOREDIR}/${JUPYTER_CONFIG}
#-----------------------------------------------------------------------------------------------------------------------------------


#add job to joblog-file ------------------------------------------------------------------------------------------------------------
LOGDIR=${HOME}"/.local/share/carme/job-log-dir"
echo -e "${SLURM_JOB_ID}\t${SLURM_JOB_NAME}\t$(hostname)\t${NODELIST}\t${STARTTIME}\t${ENDTIME}" >> ${LOGDIR}/job-log.dat
#-----------------------------------------------------------------------------------------------------------------------------------


#register job with frontend db -----------------------------------------------------------------------------------------------------
${CARME_SCRIPT_PATH}/dist_alter_jobDB_entry/alter_jobDB_entry ${DBJOBID} ${URL} ${SLURM_JOB_ID} ${HASH} ${IPADDR} ${NB_PORT} ${TB_PORT} ${GPU_DEVICES} ${CARME_BACKEND_SERVER} ${CARME_BACKEND_PORT}
#-----------------------------------------------------------------------------------------------------------------------------------


#crate SSD scratch folder-----------------------------------------------------------------------------------------------------------
if [ ${IPADDR} != "192.168.152.11" ];then
  mkdir /scratch_local/${SLURM_JOB_ID}
  echo "/home/SSD is a fast local scratch storage. WARMING: everything will be deleted at the end of this job!" > /scratch_local/${SLURM_JOB_ID}/readme.md
fi
#-----------------------------------------------------------------------------------------------------------------------------------


#start singularity -----------------------------------------------------------------------------------------------------------------
export XDG_RUNTIME_DIR=""
if [[ ${IMAGE} = *"scratch_image_build"* ]];then #sandbox image - add own start script
  echo "Sandox Mode" ${IMAGE} ${MOUNTS}
  newpid sudo singularity exec -B /etc/libibverbs.d ${MOUNTS} --writable ${IMAGE} /bin/bash /home/.CarmeScripts/start_build_job.sh ${IPADDR} ${NB_PORT} ${TB_PORT} ${TA_PORT} ${USER} ${HASH} ${GPU_DEVICES}
else
		if [ ${IPADDR} != "192.168.152.11" ];then
    newpid singularity exec -B /etc/libibverbs.d ${MOUNTS} -B /scratch_local/${SLURM_JOB_ID}:/home/SSD ${IMAGE} /bin/bash /home/.CarmeScripts/start_master.sh ${IPADDR} ${NB_PORT} ${TB_PORT} ${TA_PORT} ${USER} ${HASH} ${GPU_DEVICES} ${MEM} ${GPUS}
		else
		  newpid singularity exec -B /etc/libibverbs.d ${MOUNTS} ${IMAGE} /bin/bash /home/.CarmeScripts/start_master.sh ${IPADDR} ${NB_PORT} ${TB_PORT} ${TA_PORT} ${USER} ${HASH} ${GPU_DEVICES} ${MEM} ${GPUS}
		fi
fi
#-----------------------------------------------------------------------------------------------------------------------------------

