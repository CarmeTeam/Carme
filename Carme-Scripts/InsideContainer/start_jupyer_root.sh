#!/bin/bash 
IPADDR=$1
NB_PORT=$2
TB_PORT=$3
USER=$4
HASH=$5
GPUS=$6
export CUDA_VISIBLE_DEVICES=$GPUS

NBDIR="/root/.jupyter"                                                                                                                                                                                   
if [ ! -d $NBDIR ]; then                                                                                                                                                                                             mkdir $NBDIR
fi            
chmod -R 777 /tmp
echo "c.NotebookApp.disable_check_xsrf = True" > /root/.jupyter/jupyter_notebook_config.py                                                                                                                 
echo "c.NotebookApp.token = ''" >> /root/.jupyter/jupyter_notebook_config.py                                                                                                                               
echo "c.NotebookApp.base_url = '/nb_${HASH}'" >> /root/.jupyter/jupyter_notebook_config.py                                                                                                                 
echo -e "$SLURM_JOBID\t$(hostname)\t$PWD/slurmjob.sh" >> /root/.job-log.dat 
/opt/anaconda3/bin/jupyter lab --ip=$IPADDR --port=$NB_PORT --notebook-dir=/home --no-browser --allow-root &
/opt/anaconda3/bin/tensorboard tensorboard --logdir="/root/tensorboard" --port=${TB_PORT} --path_prefix="/tb_${HASH}"   

