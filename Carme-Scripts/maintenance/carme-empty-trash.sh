#!/bin/bash

# script to empty the local trash as jupyter moves the deleted files to ./local/share/Trash and there is no global delete button in 
# jupyter-lab
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

#-----------------------------------------------------------------------------------------------------------------------------------


find /home -path "*.local/share/Trash/files" -exec rm -vr "{}" \;
find /home -path "*.local/share/Trash/info" -exec rm -vr "{}" \;

