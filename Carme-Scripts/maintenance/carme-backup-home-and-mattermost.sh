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
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=$(echo "$variable_value" | tr -d '"')
    echo $variable_value
  }
else
  printf "${SETCOLOR}no config-file found in $CLUSTER_DIR${NOCOLOR}\n"
  exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from config
CARME_HEADNODE_IP=$(get_variable CARME_HEADNODE_IP $CLUSTER_DIR/${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

THIS_NODE_IPS=( $(hostname -I) )
if [[ ! " ${THIS_NODE_IPS[@]} " =~ " ${CARME_HEADNODE_IP} " ]]; then
    printf "${SETCOLOR}this is not the Headnode${NOCOLOR}\n"
    exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------

# backup /home
PATH_TO_HOME="/mnt/beegfs/home/"
PATH_TO_HOMEBACKUP="/mnt/beegfs/home_backup/"
time rsync -avhPHAX --stats --delete $PATH_TO_HOME $PATH_TO_HOMEBACKUP

# backup mattermostdata
if [ $CARME_MATTERMOST_TRIGGER = "yes" ]; then
		PATH_TO_MATTERMOSTDATA="/mnt/beegfs/mattermost-data/"
		PATH_TO_MATTERMOSTDATABACKUP="/mnt/beegfs/mattermost-data_backup/"
  time rsync -avhPHAX --stats --delete $PATH_TO_MATTERMOSTDATA $PATH_TO_MATTERMOSTDATABACKUP
fi

