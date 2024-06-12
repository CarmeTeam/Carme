#!/bin/bash
#-----------------------------------------------------------------------------------------#
#----------------------------------- SLURM installation ----------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then

  CARME_SLURM=$(get_variable CARME_SLURM ${FILE_START_CONFIG})
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})

  [[ -z ${CARME_SLURM} ]] && die "[remove_slurm.sh]: CARME_SLURM not set."
  [[ -z ${CARME_SYSTEM} ]] && die "[remove_slurm.sh]: CARME_SYSTEM not set."
  [[ -z ${CARME_NODE_LIST} ]] && die "[remove_slurm.sh]: CARME_NODE_LIST not set."

else
  die "[remove_slurm.sh]: ${FILE_START_CONFIG} not found."
fi

# check variables --------------------------------------------------------------------------
log "checking variables..."

if ! [[ ${CARME_SYSTEM} == "single" || ${CARME_SYSTEM} == "multi" ]]; then
  die "[remove_slurm.sh]: CARME_SYSTEM in CarmeConfig.start was not set properly. It must be single or multi."
fi
if ! [[ ${CARME_SLURM} == "yes" || ${CARME_SLURM} == "no" ]]; then
  die "[remove_slurm.sh]: CARME_SLURM in CarmeConfig.start was not set properly. It must be yes or no."
fi

# remove logs -----------------------------------------------------------------------------
log "removing logs..."

if [[ ${CARME_SLURM} == "yes" ]]; then
  rm -rf /var/log/slurm
  rm -rf /var/log/carme
elif [[ ${CARME_SLURM} == "no" ]]; then
  rm -rf /var/log/carme
fi

if [[ ${CARME_SYSTEM} == "multi" ]]; then
  for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
    if [[ ${CARME_SLURM} == "yes" ]]; then
      ssh ${COMPUTE_NODE} "rm -rf /var/log/slurm"
      ssh ${COMPUTE_NODE} "rm -rf /var/log/carme"
    elif [[ ${CARME_SLURM} == "no" ]]; then
      ssh ${COMPUTE_NODE} "rm -rf /var/log/carme"	    
    fi
  done  
fi

# remove packages -------------------------------------------------------------------------

if [[ ${CARME_SLURM} == "yes" ]]; then
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    log "removing slurm packages..."
    apt-get purge --auto-remove slurmd -y
    apt-get purge --auto-remove slurmdbd -y
    apt-get purge --auto-remove slurmctld -y
    apt-get purge --auto-remove libpmix-dev -y
    systemctl daemon-reload
    systemctl reset-failed
    log "slurm successfully removed."
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    log "removing slurm packages in the head-node..."
    apt-get purge --auto-remove slurmdbd -y
    apt-get purge --auto-remove slurmctld -y
    apt-get purge --auto-remove libpmix-dev -y
    systemctl daemon-reload
    systemctl reset-failed
	  
    for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      log "removing slurm packages in the compute-node ${COMPUTE_NODE}..."
      ssh ${COMPUTE_NODE} "apt-get purge --auto-remove slurmd -y"
      ssh ${COMPUTE_NODE} "apt-get purge --auto-remove slurm-client -y"
      ssh ${COMPUTE_NODE} "apt-get purge --auto-remove libpmix-dev -y"
      ssh ${COMPUTE_NODE} "systemctl daemon-reload"
      ssh ${COMPUTE_NODE} "systemctl reset-failed"
    done
    log "slurm successfully removed."
  fi
elif [[ ${CARME_SLURM} == "no" ]]; then
  log "carme in slurm successfully removed."
fi
