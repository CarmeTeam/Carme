#!/bin/bash 
IPADDR=$1
NB_PORT=$2
TB_PORT=$3
USER=$4
HASH=$5
GPUS=$6

chmod -R 1777 /tmp

# start theia ----------------------------------------------------------------------------------------------------------------------
THEIA_BASE_DIR="/opt/theia-ide/"
if [ -d ${THEIA_BASE_DIR} ]; then
  THEIA_JOB_TMP=${HOME}"/carme_tmp/"${SLURM_JOBID}"_job_tmp"
  mkdir -p $THEIA_JOB_TMP
  cd ${THEIA_BASE_DIR}
  PATH=/opt/anaconda3/bin/:$PATH TMPDIR=$THEIA_JOB_TMP TMP=$THEIA_JOB_TMP TEMP=$THEIA_JOB_TMP /opt/anaconda3/bin/node node_modules/.bin/theia start ${HOME} --hostname $IPADDR --port $TA_PORT --startup-timeout -1 &
  cd
fi
#-----------------------------------------------------------------------------------------------------------------------------------

# start jupyter-lab ----------------------------------------------------------------------------------------------------------------
LOGDIR=${HOME}"/.local/share/carme/job-log-dir-"$(date +"%Y")
/opt/anaconda3/bin/jupyter lab --ip=${IPADDR} --port=${NB_PORT} --notebook-dir=/home --no-browser --config=${LOGDIR}/${SLURM_JOB_ID}-jupyter_notebook_config.py --allow-root
#-----------------------------------------------------------------------------------------------------------------------------------


