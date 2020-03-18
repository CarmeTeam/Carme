#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to add new users to slurm
#
# Copyright (C) 2020 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------
echo ""


# source basic bash functions ------------------------------------------------------------------------------------------------------
PATH_TO_SCRIPTS_FOLDER="/opt/Carme/Carme-Scripts"
if [ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  echo "ERROR: carme-basic-bash-functions.sh not found but needed"
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# some basic checks before we continue ---------------------------------------------------------------------------------------------
# check if bash is used to execute the script
is_bash

# check if root executes this script
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# load variables from config -------------------------------------------------------------------------------------------------------
CARME_SLURM_ControlAddr=$(get_variable CARME_SLURM_ControlAddr)
CARME_SLURM_ClusterName=$(get_variable CARME_SLURM_ClusterName)
#-----------------------------------------------------------------------------------------------------------------------------------


# functions ------------------------------------------------------------------------------------------------------------------------
if [ -f "${PATH_TO_SCRIPTS_FOLDER}/slurm/carme-slurm-mgmt-functions.sh" ];then
  source "${PATH_TO_SCRIPTS_FOLDER}/slurm/carme-slurm-mgmt-functions.sh"
else
  echo "ERROR: carme-slurm-mgmt-functions.sh not found but needed"
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if this node is the slurmctld node -----------------------------------------------------------------------------------------
check_if_slurmctld_node "${CARME_SLURM_ControlAddr}"
#-----------------------------------------------------------------------------------------------------------------------------------


read -rp "Do you want to delete (a) user(s) from slurm database? [y/N] ${LBR}" RESP
echo ""
if [ "$RESP" = "y" ]; then

  read -rp "enter slurm-user(s) that you want to delete [multiple users separated by space] ${LBR}" SLURMUSER_HELPER
  echo ""

  for SLURMUSER in $SLURMUSER_HELPER
  do
    # check if user exists
    check_if_user_exists "${SLURMUSER}"
    
    # detzermine slurm accounts a user belongs to
    list_slurm_accounts "${SLURMUSER}"
    
    # delete user from slurm db
    sacctmgr delete user name="${SLURMUSER}" cluster="${CARME_SLURM_ClusterName}" account="${CARME_SLURM_ACCOUNT}"
  done
else
  echo "Bye Bye..."
  exit 137
fi
