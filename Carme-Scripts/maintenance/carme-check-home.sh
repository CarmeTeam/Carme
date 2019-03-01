#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to check if home is mounted and not print a message in mattermost
# script usable in crontab
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

#-----------------------------------------------------------------------------------------------------------------------------------

HOST=$(hostname)
#printf "$HOST\n"
PAYLOAD="payload={\"text\": \" $HOST : /home is not mounted\"}"
#printf "$PAYLOAD\n"

if [[ ! $(findmnt -M /home/) ]]; then
    #printf "not mounted\n"
    curl -i -X POST --data-urlencode "$PAYLOAD" $CARME_MATTERMOST_WEBHOCK
    printf "\n"
fi


