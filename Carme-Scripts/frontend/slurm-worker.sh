#!/bin/bash
# a simple bash script to start a singularity image
#
# usage: slurm JOBID IMAGE MOUNTS NUM_GPUS_PER_NODE Mem_limits
#
# @ Dr. Dominik Straßel, Janis Keuper 2018
#-----------------------------------------------------------------------------------------------------------------------------------


LOGDIR="/home/$USER/.job-log-dir"
if [ ! -d $LOGDIR ]; then
    mkdir $LOGDIR
fi
#-----------------------------------------------------------------------------------------------------------------------------------
cd /home/$USER/
DBJOBID=$1
IMAGE=$2
mountstr=$3  
GPUS=$4
MEM=$5
CARME_SCRIPT_PATH=$6
GPU_TYPE=$7

#read user accessable part of CarmeConfig                              
source ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container   
MOUNTS=${mountstr//[_]/ }

IPADDR=$(ip route get ${CARME_GATEWAY} | head -1 | awk '{print $5}' | cut -d/ -f1)
if [[ -z $IPADDR ]];then
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
if [[ -z "$GPU_DEVICES" ]];then
  echo "ERROR: WORKER: available GPUs not set!"
  echo "ERROR: WORKER: no free GPUs on node. Job stops now!"
  echo "ERROR: please contact your admin."
  exit 137
fi

echo "WORKER GPUS: " $IPADDR $GPUS $GPU_DEVICES
if [[ "${GPU_TYPE}" == "default" ]];then
  echo "WORKER GPUS: #(GPUS): ${GPUS}, GPU-Devices: ${GPU_DEVICES}, GPU type not specified"
else
		echo "MASTER GPUS: #(GPUs): ${GPUS}, GPU-Devices: ${GPU_DEVICES}, GPU type: ${GPU_TYPE}"
fi
echo ""

#crate SSD scratch folder------------------------------------
if [[ -d /scratch_local ]];then
  mkdir -p /scratch_local/$SLURM_JOBID
  echo "/home/SSD is a fast local scratch storage. WARMING: everything will be deleted at the end of this job!" > /scratch_local/$SLURM_JOBID/readme.md
else
	 echo "ERROR: WORKER: cannot create folder on local SSD"
		echo "               SSD parent folder not found"
fi
#-------------------------------------------------------------                        

#start singularity ------------------------------------
newpid singularity exec -B /etc/libibverbs.d $MOUNTS -B /scratch_local/$SLURM_JOBID:/home/SSD $IMAGE /bin/bash /home/.CarmeScripts/start_worker.sh $IPADDR $NB_PORT $TB_PORT $USER $HASH $GPU_DEVICES $MEM 
#------------------------------------------------------

