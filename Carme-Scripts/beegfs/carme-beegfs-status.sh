#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to check the status of beegfs
#
# Copyright (C) 2018 by Dr. Dominik Straßel
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
check_command systemctl
check_command hostname
#-----------------------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from config
CARME_BEEGFS_MGMTNODE_IP=$(get_variable CARME_BEEGFS_MGMTNODE_IP)
CARME_BEEGFS_METANODES=$(get_variable CARME_BEEGFS_METANODES)
CARME_NODES_LIST=$(get_variable CARME_NODES_LIST)
CARME_BEEGFS_STORAGENODES=$(get_variable CARME_BEEGFS_STORAGENODES)

[[ -z ${CARME_BEEGFS_MGMTNODE_IP} ]] && die "CARME_BEEGFS_MGMTNODE_IP not set"
[[ -z ${CARME_BEEGFS_METANODES} ]] && die "CARME_BEEGFS_METANODES not set"
[[ -z ${CARME_NODES_LIST} ]] && die "CARME_NODES_LIST not set"
[[ -z ${CARME_BEEGFS_STORAGENODES} ]] && die "CARME_BEEGFS_STORAGENODES not set"
#-----------------------------------------------------------------------------------------------------------------------------------

THIS_NODE_IPS=( "$(hostname -I)" )
if [[ ! " ${THIS_NODE_IPS[*]} " =~ ${CARME_BEEGFS_MGMTNODE_IP} ]]; then
  echo "ERROR: this is not the BeeGFS-Mgmt-Node"
  exit 200
fi

#----------------------------------------------------------------------------------------------------------------------------------- 

read -rp "Do you want to check the status of BeeGFS? [y/N] " RESP
echo ""
if [[ "$RESP" = "y" ]]; then

  # status of the beegfs-mgmtd -----------------------------------------------------------------------------------------------------
  echo "status of the beegfs-mgmtd on $(hostname -s)"
  systemctl --no-pager -l status beegfs-mgmtd
  #---------------------------------------------------------------------------------------------------------------------------------


  # status of the beegfs-meta ------------------------------------------------------------------------------------------------------
  echo ""
  for HOST in ${CARME_BEEGFS_METANODES}; do
    echo "status of the beegfs-meta on ${HOST}"
    ssh root@"${HOST}" -X -t "systemctl --no-pager -l status beegfs-meta"
  done
  #---------------------------------------------------------------------------------------------------------------------------------


  # status of the beegfs-storage ---------------------------------------------------------------------------------------------------
  echo ""
  for HOST in ${CARME_BEEGFS_STORAGENODES}; do
    echo "status of the beegfs-storage on ${HOST}"
    ssh root@${HOSTS} -X -t "systemctl --no-pager -l status beegfs-storage"
  done
  #---------------------------------------------------------------------------------------------------------------------------------


  # status of the beegfs-helperd ---------------------------------------------------------------------------------------------------
  echo ""
  echo "status of the beegfs-helperd on $(hostname -s)"
  systemctl --no-pager -l status beegfs-helperd

  for HOST in ${CARME_NODES_LIST}; do
    echo "status of the beegfs-helperd on ${HOST}"
    ssh root@"${HOST}" -X -t "systemctl --no-pager -l status beegfs-helperd"
  done
  #---------------------------------------------------------------------------------------------------------------------------------


  # status of the beegfs-client ----------------------------------------------------------------------------------------------------
  echo ""
  echo "status of the beegfs-client on $(hostname -s)"
  systemctl --no-pager -l status beegfs-client

  for HOST in ${CARME_NODES_LIST}; do
    echo "status of the beegfs-client on ${HOST}"
    ssh root@"${HOST}" -X -t "systemctl --no-pager -l status beegfs-client"
  done
  #---------------------------------------------------------------------------------------------------------------------------------


  # ls -lah /home ------------------------------------------------------------------------------------------------------------------
  echo ""
  echo "list home on $(hostname -s)"
  ls -lah /home

  for HOSTS in ${CARME_NODES_LIST}; do
    echo "list /home on ${HOST}"
    ssh root@"${HOST}" -X -t "ls -lah /home"
  done
  #---------------------------------------------------------------------------------------------------------------------------------

else

  echo "Bye Bye..."

fi
