#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to stop beegfs
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
    source $CLUSTER_DIR/$CONFIG_FILE
else
    printf "${SETCOLOR}no config-file found in $CLUSTER_DIR${NOCOLOR}\n"
    exit 137
fi

THIS_NODE_IPS=( $(hostname -I) )
#echo ${THIS_NODE_IPS[@]}
if [[ ! " ${THIS_NODE_IPS[@]} " =~ " ${CARME_HEADNODE_IP} " ]]; then
    printf "${SETCOLOR}this is not the Headnode${NOCOLOR}\n"
    exit 137
fi

read -p "Do you want to execute a command on all compute nodes? [y/N] " RESP
if [ "$RESP" = "y" ]; then
    printf "\n"
    read -p "type command you want to execute: " NODE_EXEC

    for HOSTS in $CARME_NODES_LIST; do
        printf "\n${SETCOLOR}--------------------${NOCOLOR}\n" 
        printf "${SETCOLOR}${HOSTS}${NOCOLOR}\n"
        ssh root@${HOSTS} -X -t "${NODE_EXEC}"
    done
    
    printf "\n"
    printf "${SETCOLOR}command was executed${NOCOLOR}\n\n"
else
    printf "${SETCOLOR}Bye Bye...${NOCOLOR}\n\n"
fi

