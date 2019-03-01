#!/bin/bash
# ----------------------------------------------
# Carme                                         
# ----------------------------------------------
# slurm-parallel.sh - start multi-node jobs
# 
# usage: slurm-parallel $DBJOBID $IMAGE $MOUNTS $NUM_GPUS_PER_NODE $MEM $NTASKS $WORKER_NODES
#                                               
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#                                                   
# Copyright 2019 by Fraunhofer ITWM                 
# License: http://open-carme.org/LICENSE.md         
# Contact: info@open-carme.org                      
# ---------------------------------------------   

DBJOBID=$1
IMAGE=$2
mountstr=$3
GPUS=$4
MEM=$5   
CARME_SCRIPT_PATH=$6
NCPU=$7
WORKER_NODES=$8

#read user accessable pert of CarmeConfig                                 
source ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container      

#SRUN="srun --exclusive -N1 -n1"
# N == Nodes
# n == CPUs/Cores

NR_PROCS=$(($SLURM_NNODES))
printf "SLURM-NNodes: $NR_PROCS\n"
printf "SLURM-Nodelist: $SLURM_JOB_NODELIST\n"
printf "\n"

scontrol show hostname $SLURM_JOB_NODELIST | paste -d, -s > $HOME/.job-log-dir/carme_nodelist_$SLURM_JOBID

for PROC in $(seq 0 $(($NR_PROCS-1)));
do
        if [ $PROC = "0" ];then
            # do something different on the master node
												echo "MASTER args $@"
            srun --exclusive -N1 -n1 -c$NCPU ${CARME_SCRIPT_PATH}/slurm.sh "$@" &
            pids[${PROC}]=$!    #Save PID of this background process
        else
												echo "WORKER args $@"
            srun --exclusive -N$WORKER_NODES -n$WORKER_NODES -c$NCPU ${CARME_SCRIPT_PATH}/slurm-worker.sh "$@" &
            pids[${PROC}]=$!    #Save PID of this background process
        fi
done

for pid in ${pids[*]};
do
    wait ${pid} #Wait on all PIDs, this returns 0 if ANY process fails
done
