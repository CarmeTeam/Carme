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
#-----------------------------------------------------------------------------------------------------------------------------------


# load variables from config -------------------------------------------------------------------------------------------------------
CARME_SLURM_ControlAddr=$(get_variable CARME_SLURM_ControlAddr)
CARME_SLURM_ClusterName=$(get_variable CARME_SLURM_ClusterName)

[[ -z ${CARME_SLURM_ControlAddr} ]] && die "CARME_SLURM_ControlAddr is not set"
[[ -z ${CARME_SLURM_ClusterName} ]] && die "CARME_SLURM_ClusterName is not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# functions ------------------------------------------------------------------------------------------------------------------------
if [ -f "${PATH_TO_SCRIPTS_FOLDER}/slurm/carme-slurm-mgmt-functions.sh" ];then
  source "${PATH_TO_SCRIPTS_FOLDER}/slurm/carme-slurm-mgmt-functions.sh"
else
  die "carme-slurm-mgmt-functions.sh not found but needed"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if this node is the slurmctld node -----------------------------------------------------------------------------------------
check_if_slurmctld_node "${CARME_SLURM_ControlAddr}"
#-----------------------------------------------------------------------------------------------------------------------------------


read -rp "Do you want to add a new user to the slurm database (cluster=${CARME_SLURM_ClusterName})? [y|N] ${LBR}" RESP
echo ""

if [ "${RESP}" = "y" ];then

  read -rp "enter the ldap-username of the new slurm-user ${LBR}" SLURMUSER
  echo ""

  # check if user exists
  check_if_user_exists "${SLURMUSER}"

  # read user limits from terminal
  read_and_check_slurm_limitations "${SLURMUSER}" "${SLURMUSER_HELPER[*]}"

  # put together what we have so far
  put_together_and_check "${SLURMUSER}" "${CARME_SLURM_ClusterName}" "${CARME_SLURM_ACCOUNT}" "${SLURM_ADMIN_LEVEL}" "${SLURM_PARTITION_LIST}" "${SLURM_ADDITIONAL_LIMITS}"

  # add user to slurm db
  echo ""
  if [[ -z "${SLURM_ADDITIONAL_LIMITS}" ]];then
    sacctmgr -i create user name="${SLURMUSER}" cluster="${CARME_SLURM_ClusterName}" account="${CARME_SLURM_ACCOUNT}" AdminLevel="${SLURM_ADMIN_LEVEL}" partition="${SLURM_PARTITION_LIST}"
  else
    sacctmgr -i create user name="${SLURMUSER}" cluster="${CARME_SLURM_ClusterName}" account="${CARME_SLURM_ACCOUNT}" AdminLevel="${SLURM_ADMIN_LEVEL}" partition="${SLURM_PARTITION_LIST}" "${SLURM_ADDITIONAL_LIMITS}"
  fi

  scontrol reconfig

else

  echo "Bye Bye..."

fi
