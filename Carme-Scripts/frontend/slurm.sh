#!/bin/bash
# ----------------------------------------------  
# Carme
# ----------------------------------------------   
# slurm.sh   
#
# see Carme development guide for documentation:   
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md 
# * Carme/Carme-Doc/DevelDoc/BackendDocu.md  
#
# Copyright 2019 by Fraunhofer ITWM  
# License: http://open-carme.org/LICENSE.md   
# Contact: info@open-carme.org  
# ---------------------------------------------   

# external variables ----------------------------------  
DBJOBID=$1
IMAGE=$2
mountstr=$3
GPUS=$4
MEM=$5
CARME_SCRIPT_PATH=$6
GPU_TYPE=$7

#read user accessable part of CarmeConfig
source ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container 
echo "Carme Verison: ${CARME_VERSION}"
echo ""

MOUNTS=${mountstr//[_]/ }   
export HASH=$(sh ${CARME_SCRIPT_PATH}/hash.sh) 
URL=${CARME_URL}/nb_$HASH 

IPADDR=$(ip route get ${CARME_GATEWAY} | head -1 | awk '{print $5}' | cut -d/ -f1)
if [[ -z $IPADDR ]];then
  echo "ERROR: IP not set!"
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------

#set variables and environment stuff -----------------------------------------------------------------------------------------------

#check if log directory exists ------------------------
LOGDIR="/home/${USER}/.job-log-dir"
if [ ! -d $LOGDIR ]; then
    mkdir $LOGDIR
fi
#------------------------------------------------------

echo "Check Parameters:"
echo "                 - IP: ${IPADDR}"
echo "                 - Backend-Server: ${CARME_BACKEND_SERVER}:${CARME_BACKEND_PORT}"
echo "                 - Image: ${IMAGE}"
echo ""

GPU_DEVICES=${CUDA_VISIBLE_DEVICES}
if [[ -z "$GPU_DEVICES" ]];then
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
#------------------------------------------------------


#compute ports: base port + first GPU id --------------
offset=${GPU_DEVICES:0:1}
NB_PORT=$((8088 + offset))
TB_PORT=$((6668 + offset))
TA_PORT=$((TB_PORT + 10))
#------------------------------------------------------


#change dir to user home ------------------------------
cd /home/${USER}/
#------------------------------------------------------


#check if carme_tmp exists ----------------------------
CARME_TMP=${HOME}"/carme_tmp/"
if [ ! -d $CARME_TMP ];then
  mkdir $CARME_TMP
fi
#------------------------------------------------------


#set jupyter parameters and settings ------------------
NBDIR="/home/$USER/.jupyter" 
if [ ! -d $NBDIR ];then
  mkdir $NBDIR                                                                                                                                                                          
fi

echo "c.NotebookApp.disable_check_xsrf = True" > /home/${USER}/.job-log-dir/${SLURM_JOBID}-jupyter_notebook_config.py
echo "c.NotebookApp.token = ''" >> /home/${USER}/.job-log-dir/${SLURM_JOBID}-jupyter_notebook_config.py
echo "c.NotebookApp.base_url = '/nb_${HASH}'" >> /home/${USER}/.job-log-dir/${SLURM_JOBID}-jupyter_notebook_config.py 
#idel job time outs
#echo "c.MappingKernelManager.cull_idle_timeout = 3600" >> /home/${USER}/.jupyter/jupyter_notebook_config.py
#echo "c.NotebookApp.shutdown_no_activity_timeout = 3600" >> /home/${USER}/.jupyter/jupyter_notebook_config.py
#------------------------------------------------------


#add job to joblog-file -------------------------------
echo -e "${SLURM_JOBID}\t${SLURM_JOB_NAME}\t$(hostname)\t${PWD}/slurmjob.sh" >> /home/${USER}/.job_log.dat
#------------------------------------------------------


#register job with frontend db ------------------------
${CARME_SCRIPT_PATH}/dist_alter_jobDB_entry/alter_jobDB_entry $DBJOBID $URL $SLURM_JOBID $HASH $IPADDR $NB_PORT $TB_PORT $GPU_DEVICES $CARME_BACKEND_SERVER $CARME_BACKEND_PORT
#------------------------------------------------------


#set job nodelist -------------------------------------
scontrol show hostname $SLURM_JOB_NODELIST | paste -d, -s > $HOME/.job-log-dir/${SLURM_JOBID}-nodelist

#-----------------------------------------------------------------------------------------------------------------------------------

#crate SSD scratch folder------------------------------------
if [ $IPADDR != "192.168.152.11" ];then
  mkdir /scratch_local/$SLURM_JOBID
  echo "/home/SSD is a fast local scratch storage. WARMING: everything will be deleted at the end of this job!" > /scratch_local/$SLURM_JOBID/readme.md
fi
#-------------------------------------------------------------


#start singularity ------------------------------------
export XDG_RUNTIME_DIR=""
if [[ $IMAGE = *"scratch_image_build"* ]];then #sandbox image - add own start script
  echo "Sandox Mode" $IMAGE $MOUNTS
  newpid sudo singularity exec -B /etc/libibverbs.d $MOUNTS --writable $IMAGE /bin/bash /home/.CarmeScripts/start_jupyer_root.sh $IPADDR $NB_PORT $TB_PORT $TA_PORT $USER $HASH $GPU_DEVICES 
else
  #echo "starting Master on" $IPADDR $GPU_DEVICES	$MEM
		if [ $IPADDR != "192.168.152.11" ];then
    newpid singularity exec -B /etc/libibverbs.d $MOUNTS -B /scratch_local/$SLURM_JOBID:/home/SSD $IMAGE /bin/bash /home/.CarmeScripts/start_jupyer.sh $IPADDR $NB_PORT $TB_PORT $TA_PORT $USER $HASH $GPU_DEVICES $MEM 
		else
		  newpid singularity exec -B /etc/libibverbs.d $MOUNTS $IMAGE /bin/bash /home/.CarmeScripts/start_jupyer.sh $IPADDR $NB_PORT $TB_PORT $TA_PORT $USER $HASH $GPU_DEVICES $MEM 
		fi
fi

#-----------------------------------------------------------------------------------------------------------------------------------

#remove temporary jobfiles ----------------------------
rm ${HOME}/.carme/.bash_carme_$SLURM_JOBID

THEIA_JOB_TMP=${HOME}"/carme_tmp/"${SLURM_JOBID}"_job_tmp"
rm -r $THEIA_JOB_TMP

#add log entry "done" ---------------------------------
sed -i "s/\\($SLURM_JOBID\\)\\(.*$\\)/\\1\\2\t<<DONE>>/" /home/${USER}/job_log.dat
#-----------------------------------------------------------------------------------------------------------------------------------

