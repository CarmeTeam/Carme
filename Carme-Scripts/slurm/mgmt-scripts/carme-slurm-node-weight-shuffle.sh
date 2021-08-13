#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to stop beegfs
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
PATH_TO_SCRIPTS_FOLDER="/opt/Carme/Carme-Scripts"
if [ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  die "carme-basic-bash-functions.sh not found but needed"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# some basic checks before we continue ---------------------------------------------------------------------------------------------
# check if bash is used to execute the script
is_bash

# check if root executes this script
is_root
#----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command grep
check_command sed
check_command scp
check_command scontrol
#-----------------------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------------------
# variables from config
CARME_SLURM_ControlAddr=$(get_variable CARME_SLURM_ControlAddr)
CARME_SLURM_CONFIG_FILE=$(get_variable CARME_SLURM_CONFIG_FILE)
CARME_NODES_LIST=$(get_variable CARME_NODES_LIST)
CARME_SLURM_BackupController=$(get_variable CARME_SLURM_BackupController)

[[ -z ${CARME_SLURM_ControlAddr} ]] && die "CARME_SLURM_ControlAddr is unset"
[[ -z ${CARME_SLURM_CONFIG_FILE} ]] && die "CARME_SLURM_CONFIG_FILE is unset"
[[ -z ${CARME_NODES_LIST} ]] && die "CARME_NODES_LIST is unset"
[[ -z ${CARME_SLURM_BackupController} ]] && die "CARME_SLURM_BackupController is unset"
#-----------------------------------------------------------------------------------------------------------------------------------


# functions ------------------------------------------------------------------------------------------------------------------------
if [ -f "${PATH_TO_SCRIPTS_FOLDER}/slurm/mgmt-scripts/carme-slurm-mgmt-functions.sh" ];then
  source "${PATH_TO_SCRIPTS_FOLDER}/slurm/mgmt-scripts/carme-slurm-mgmt-functions.sh"
else
  echo "ERROR: carme-slurm-mgmt-functions.sh not found but needed"
  exit 200
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if this node is the slurmctld node -----------------------------------------------------------------------------------------
check_if_slurmctld_node "${CARME_SLURM_ControlAddr}"
#-----------------------------------------------------------------------------------------------------------------------------------


# declare array to store node that have no weights
NO_WEIGHTS=()


read -rp "Do you want to shuffle the weights of the compute nodes? [y/N] " RESP
if [ "$RESP" = "y" ]; then

  # backup slurm.conf
  echo "backup slurm.conf in slurm.conf.bak"
  cp "${CARME_SLURM_CONFIG_FILE}" "${CARME_SLURM_CONFIG_FILE}.bak"

  for NODE in $CARME_NODES_LIST; do
    OLD_NODE_CONFIG="$(grep -r "NodeName=${NODE}" "${CARME_SLURM_CONFIG_FILE}")"
    
    if ! [[ "${OLD_NODE_CONFIG}" =~ "Weight" ]];then
      NO_WEIGHTS+=( "${NODE}" )
      continue
    fi

    OLD_WEIGHT="$(grep -r "NodeName=${NODE}" "${CARME_SLURM_CONFIG_FILE}" | awk -F'Weight=' '{ print $2 }')"
    NEW_WEIGHT=$(( RANDOM % 500 + 1 ))
    echo "${NODE}"
    echo "old weight: ${OLD_WEIGHT}"
    echo "new weight: ${NEW_WEIGHT}"
    echo ""

    NEW_NODE_CONFIG="${OLD_NODE_CONFIG/${OLD_WEIGHT}/${NEW_WEIGHT}}"

    sed -i 's/'"${OLD_NODE_CONFIG}"'/'"${NEW_NODE_CONFIG}"'/g' "${CARME_SLURM_CONFIG_FILE}"

  done


  # check if there are nodes without weights
  if [ ${#NO_WEIGHTS[@]} -eq 0 ]; then

    # copy new slurm config to all compute nodes
    echo "copy new slurm.conf to all nodes"
    for NODE in $CARME_NODES_LIST; do
      scp "${CARME_SLURM_CONFIG_FILE}" "${NODE}":"${CARME_SLURM_CONFIG_FILE}"
    done


    # copy new config to backupo slurm controler if it exists
    if [[ -n "$CARME_SLURM_BackupController" ]]; then
      echo "copy new slurm.conf to backup controler"
      scp "${CARME_SLURM_CONFIG_FILE}" "${CARME_SLURM_BackupController}":"${CARME_SLURM_CONFIG_FILE}"
    fi


    # reload slurm config
    echo "reload slurm.conf"
    scontrol reconfig

  else

    echo ""
    echo "ERROR: cannot create new slurm.conf as there are nodes without weights."

    echo "move slurm.conf.bak to slurm.conf"
    mv "${CARME_SLURM_CONFIG_FILE}.bak" "${CARME_SLURM_CONFIG_FILE}"

    echo "nodes without weights:"
    for NODE in "${NO_WEIGHTS[@]}";do
      echo -e "\t${NODE}"
    done

  fi

else

  echo "Bye Bye..."

fi
