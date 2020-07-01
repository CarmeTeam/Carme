#!/bin/bash

# script to empty the local trash as jupyter moves the deleted files to ./local/share/Trash and there is no global delete button in 
# jupyter-lab
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
PATH_TO_SCRIPTS_FOLDER="/opt/Carme/Carme-Scripts"
if [ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ];then
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


# get needed variables from config -------------------------------------------------------------------------------------------------
CARME_HEADNODE_IP=$(get_variable CARME_HEADNODE_IP)
#-----------------------------------------------------------------------------------------------------------------------------------


# check if node is headnode --------------------------------------------------------------------------------------------------------
THIS_NODE_IPS=( "$(hostname -I)" )
if [[ ! "${THIS_NODE_IPS[*]}" =~ ${CARME_HEADNODE_IP} ]];then
  echo "ERROR: this is not the headnode"
  exit 200
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# empty trash folder ---------------------------------------------------------------------------------------------------------------
echo "start cleaning trash folders in /home"
find /home -path "*.local/share/Trash/files" -exec rm -vr "{}" \;
find /home -path "*.local/share/Trash/info" -exec rm -vr "{}" \;
#-----------------------------------------------------------------------------------------------------------------------------------
