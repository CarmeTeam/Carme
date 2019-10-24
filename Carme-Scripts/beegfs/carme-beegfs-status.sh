#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to check the status of beegfs
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#----------------------------------------------------------------------------------------------------------------------------------- 

CLUSTER_DIR="/opt/Carme"
CONFIG_FILE="CarmeConfig"

SETCOLOR='\033[1;33m'
NOCOLOR='\033[0m'
printf "\n"
#-----------------------------------------------------------------------------------------------------------------------------------

if [ ! "$BASH_VERSION" ]; then
    printf "${SETCOLOR}This is a bash-script. Please use bash to execute it!${NOCOLOR}\n\n"
    exit 137
fi

if [ ! $(whoami) = "root" ]; then
    printf "${SETCOLOR}you need root privileges to run this script${NOCOLOR}\n\n"
    exit 137
fi

if [ -f $CLUSTER_DIR/$CONFIG_FILE ]; then
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=${variable_value%#*}
    variable_value=$(echo "$variable_value" | tr -d '"')
    echo $variable_value
  }
else
  printf "${SETCOLOR}no config-file found in $CLUSTER_DIR${NOCOLOR}\n"
  exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from config
CARME_BEEGFS_MGMTNODE_IP=$(get_variable CARME_BEEGFS_MGMTNODE_IP $CLUSTER_DIR/${CONFIG_FILE})
CARME_BEEGFS_METANODES=$(get_variable CARME_BEEGFS_METANODES $CLUSTER_DIR/${CONFIG_FILE})
CARME_NODES_LIST=$(get_variable CARME_NODES_LIST $CLUSTER_DIR/${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

THIS_NODE_IPS=( $(hostname -I) )
if [[ ! " ${THIS_NODE_IPS[@]} " =~ " ${CARME_BEEGFS_MGMTNODE_IP} " ]]; then
  printf "${SETCOLOR}this is not the BeeGFS-Mgmt-Node${NOCOLOR}\n"
  exit 137
fi

#----------------------------------------------------------------------------------------------------------------------------------- 

read -p "Do you want to check the status of BeeGFS? [y/N] " RESP
if [ "$RESP" = "y" ]; then
    printf "\n"
    printf "${SETCOLOR}BeeGFS will be checked now...${NOCOLOR}\n\n"

    # status of the beegfs-mgmtd ---------------------------------------------------------------------------------------------------
    printf "${SETCOLOR}status of the beegfs-mgmtd.service${NOCOLOR}"

    printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
    printf "${SETCOLOR}$(hostname)${NOCOLOR}\n"
    systemctl --no-pager -l status beegfs-mgmtd
    # ------------------------------------------------------------------------------------------------------------------------------


    # status of the beegfs-meta ----------------------------------------------------------------------------------------------------
    printf "\n"
    printf "${SETCOLOR}status of the beegfs-meta.service${NOCOLOR}"

    for HOSTS in $CARME_BEEGFS_METANODES; do
        printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
        printf "${SETCOLOR}${HOSTS}${NOCOLOR}\n"
        ssh root@${HOSTS} -X -t "systemctl --no-pager -l status beegfs-meta"
    done
    # ------------------------------------------------------------------------------------------------------------------------------


    # status of the beegfs-storage -------------------------------------------------------------------------------------------------
    printf "\n"
    printf "${SETCOLOR}status of the beegfs-storage.service${NOCOLOR}"

    #printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
    #printf "${SETCOLOR}$(hostname)${NOCOLOR}\n"
    #systemctl --no-pager -l status beegfs-storage

    for HOSTS in $CARME_NODES_LIST; do
        printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
        printf "${SETCOLOR}${HOSTS}${NOCOLOR}\n"
        ssh root@${HOSTS} -X -t "systemctl --no-pager -l status beegfs-storage"
    done
    # ------------------------------------------------------------------------------------------------------------------------------


    # status of the beegfs-helperd -------------------------------------------------------------------------------------------------
    printf "\n"
    printf "${SETCOLOR}status of the beegfs-helperd.service${NOCOLOR}"

    printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
    printf "${SETCOLOR}$(hostname)${NOCOLOR}\n"
    systemctl --no-pager -l status beegfs-helperd

    for HOSTS in $CARME_NODES_LIST; do
        printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
        printf "${SETCOLOR}${HOSTS}${NOCOLOR}\n"
        ssh root@${HOSTS} -X -t "systemctl --no-pager -l status beegfs-helperd"
    done
    # ------------------------------------------------------------------------------------------------------------------------------


    # status of the beegfs-client --------------------------------------------------------------------------------------------------
    printf "\n"
    printf "${SETCOLOR}status of the beegfs-client.service${NOCOLOR}"

    printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
    printf "${SETCOLOR}$(hostname)${NOCOLOR}\n"
    systemctl --no-pager -l status beegfs-client

    for HOSTS in $CARME_NODES_LIST; do
        printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
        printf "${SETCOLOR}${HOSTS}${NOCOLOR}\n"
        ssh root@${HOSTS} -X -t "systemctl --no-pager -l status beegfs-client"
    done
    # ------------------------------------------------------------------------------------------------------------------------------


    # ls -lah /home ----------------------------------------------------------------------------------------------------------------
    printf "\n"
    printf "${SETCOLOR}show /home${NOCOLOR}"

    printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
    printf "${SETCOLOR}$(hostname)${NOCOLOR}\n"
    ls -lah /home

    for HOSTS in $CARME_NODES_LIST; do
        printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
        printf "${SETCOLOR}${HOSTS}${NOCOLOR}\n"
        ssh root@${HOSTS} -X -t "ls -lah /home"
    done
    # ------------------------------------------------------------------------------------------------------------------------------

    printf "\n"
else
    printf "${SETCOLOR}Bye Bye...${NOCOLOR}\n\n"
fi

