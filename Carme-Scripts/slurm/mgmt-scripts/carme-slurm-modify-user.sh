#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to add new users to slurm
#
# Copyright (C) 2020 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
PATH_TO_SCRIPTS_FOLDER="/opt/Carme/Carme-Scripts"
if [[ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ]];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  echo "ERROR: carme-basic-bash-functions.sh not found but needed"
  exit 200
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# some basic checks before we continue ---------------------------------------------------------------------------------------------
# check if bash is used to execute the script
is_bash

# check if root executes this script
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command grep
check_command sacctmgr
#-----------------------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from config
CARME_SLURM_ControlAddr=$(get_variable CARME_SLURM_ControlAddr)
#-----------------------------------------------------------------------------------------------------------------------------------


# functions ------------------------------------------------------------------------------------------------------------------------
if [[ -f "${PATH_TO_SCRIPTS_FOLDER}/slurm/mgmt-scripts/carme-slurm-mgmt-functions.sh" ]];then
  source "${PATH_TO_SCRIPTS_FOLDER}/slurm/mgmt-scripts/carme-slurm-mgmt-functions.sh"
else
  echo "ERROR: carme-slurm-mgmt-functions.sh not found but needed"
  exit 200
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if this node is the slurmctld node -----------------------------------------------------------------------------------------
check_if_slurmctld_node "${CARME_SLURM_ControlAddr}"
#-----------------------------------------------------------------------------------------------------------------------------------


read -rp "Do you want to modify user entries in the slurm database? [y/N] " RESP
echo ""

if [[ "$RESP" = "y" ]];then

  read -rp "enter slurm-user(s) that you want to modify [multiple users separated by space]: " SLURMUSER_HELPER
  echo ""

  read -rp "enter what you want to modify: " SLURMMODIFY

  for SLURMUSER in ${SLURMUSER_HELPER};do
    echo "${SLURMUSER}"
    sacctmgr modify user "${SLURMUSER}" set "${SLURMMODIFY}"
  done

else

  echo "Bye Bye..."

fi
