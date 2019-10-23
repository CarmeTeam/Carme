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
GPU_TYPE=$9

NR_PROCS=$((${SLURM_NNODES}))
echo "SLURM-NNodes: ${NR_PROCS}"
echo "SLURM-Nodelist: ${SLURM_JOB_NODELIST}"
echo ""

for PROC in $(seq 0 $(($NR_PROCS-1)));do
  if [ $PROC = "0" ];then
    echo "MASTER args $@"
    srun --exclusive -N1 -n1 -c$NCPU ${CARME_SCRIPT_PATH}/slurm.sh "$@" &
    pids[${PROC}]=$!
  else
    echo "WORKER args $@"
    srun --exclusive -N$WORKER_NODES -n$WORKER_NODES -c$NCPU ${CARME_SCRIPT_PATH}/slurm-worker.sh "$@" &
    pids[${PROC}]=$!
  fi
done

for pid in ${pids[*]};do
  wait ${pid}
done

