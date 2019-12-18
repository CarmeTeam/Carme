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
# variables from config
CARME_MATTERMOST_WEBHOCK=$(get_variable CARME_MATTERMOST_WEBHOCK $CLUSTER_DIR/${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

HOST=$(hostname)
PAYLOAD="payload={\"text\": \" $HOST : /home is not mounted\"}"

if [[ ! $(findmnt -M /home/) ]]; then
  curl -i -X POST --data-urlencode "$PAYLOAD" $CARME_MATTERMOST_WEBHOCK
  printf "\n"
fi


