#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to stop beegfs
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

read -rp "Do you want to stop BeeGFS? [y/N] " RESP
echo ""
if [ "$RESP" = "y" ]; then

  # umount /home -------------------------------------------------------------------------------------------------------------------
  echo "umount /home on $(hostname)"
  umount -v /home

  for HOST in ${CARME_NODES_LIST}; do
    echo "umount /home on ${HOST}"
    ssh root@"${HOST}" -X -t "umount -v /home"
  done
  #---------------------------------------------------------------------------------------------------------------------------------


  # stop the beegfs-client ---------------------------------------------------------------------------------------------------------
  echo ""
  echo "stop the beegfs-client on $(hostname)"
  systemctl stop beegfs-client && systemctl --no-pager -l status beegfs-client

  for HOST in ${CARME_NODES_LIST}; do
    echo "stop the beegfs-client on ${HOST}"
    ssh root@"${HOST}" -X -t "systemctl stop beegfs-client && systemctl --no-pager -l status beegfs-client"
  done
  #---------------------------------------------------------------------------------------------------------------------------------


  # stop the beegfs-helperd --------------------------------------------------------------------------------------------------------
  echo ""
  echo "stop the beegfs-helperd on $(hostname)"
  systemctl stop beegfs-helperd && systemctl --no-pager -l status beegfs-helperd

  for HOST in ${CARME_NODES_LIST}; do
    echo "stop the beegfs-helperd on ${HOST}"
    ssh root@"${HOST}" -X -t "systemctl stop beegfs-helperd && systemctl --no-pager -l status beegfs-helperd"
  done
  #---------------------------------------------------------------------------------------------------------------------------------


  # stop the beegfs-storage --------------------------------------------------------------------------------------------------------
  echo ""
  for HOST in ${CARME_BEEGFS_STORAGENODES}; do
    echo "stop the beegfs-storage on ${HOST}"
    ssh root@"${HOST}" -X -t "systemctl stop beegfs-storage && systemctl --no-pager -l status beegfs-storage"
  done
  #---------------------------------------------------------------------------------------------------------------------------------


  # stop the beegfs-meta -----------------------------------------------------------------------------------------------------------
  echo ""
  for HOST in ${CARME_BEEGFS_METANODES}; do
    echo "stop the beegfs-meta on ${HOST}"
    ssh root@"${HOST}" -X -t "systemctl stop beegfs-meta && systemctl --no-pager -l status beegfs-meta"
  done
  #---------------------------------------------------------------------------------------------------------------------------------


  # stop the beegfs-mgmtd ----------------------------------------------------------------------------------------------------------
  echo ""
  echo "stop the beegfs-mgmtd on $(hostname)"
  systemctl stop beegfs-mgmtd && systemctl --no-pager -l status beegfs-mgmtd
  # --------------------------------------------------------------------------------------------------------------------------------

else

  echo "Bye Bye..."

fi
