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

#read user accessable part of CarmeConfig                              
source ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container   
MOUNTS=${mountstr//[_]/ }

IPADDR=$(ip route get ${CARME_GATEWAY} | head -1 | awk '{print $5}' | cut -d/ -f1)

#dummy valuse
NB_PORT=0
TB_PORT=0

GPU_DEVICES=$( ${CARME_SCRIPT_PATH}/dist_get_free_gpu_on_host/get_free_gpu_on_host $IPADDR $GPUS $CARME_BACKEND_SERVER $CARME_BACKEND_PORT) 
GPU_DEVICES=${CUDA_VISIBLE_DEVICES}
if [[ -z "$GPU_DEVICES" ]];then
  echo "ERROR: WORKER: available GPUs not set!"
  echo "ERROR: WORKER: no free GPUs on node. Job stops now!"
  echo "ERROR: please contact your admin."
  exit 137
fi
echo "WORKER GPUS: " $IPADDR $GPUS $GPU_DEVICES
#GPU_DEVICES='1,0' #mult-node jobs are exclusive!

#crate SSD scratch folder------------------------------------
mkdir /scratch_local/$SLURM_JOBID
echo "/home/SSD is a fast local scratch storage. WARMING: everything will be deleted at the end of this job!" > /scratch_local/$SLURM_JOBID/readme.md

#rm old job scratch dirs
#squeue --noheader --format=%i | sort > /scratch_local/joblist
#ls /scratch_local | sort > /scratch_local/dirlist
#comm -23 /scratch_local/dirlist /scratch_local/joblist | xargs -i rm -r /scratch_local/{}
#-------------------------------------------------------------                        

#start singularity ------------------------------------
echo "starting worker on" $IPADDR $GPU_DEVICES  
newpid singularity exec -B /etc/libibverbs.d $MOUNTS -B /scratch_local/$SLURM_JOBID:/home/SSD $IMAGE /bin/bash /home/.CarmeScripts/start_worker.sh $IPADDR $NB_PORT $TB_PORT $USER $HASH $GPU_DEVICES $MEM 
#------------------------------------------------------

