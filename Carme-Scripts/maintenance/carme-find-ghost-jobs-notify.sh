#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to check if we have ghost jobs running on a node and notify in mattermost
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

KILLLIST=( $(ps axo user:20,stat,ppid,pid,comm | grep -w Sl | awk '$3 == "1" && !/root|daemon|message|sys|who|nvidia|lightdm|zabbix|munge|kern|statd|ntp/ { printf "%-15s %-5s %-7s %-7s %-7s\n", $1, $2, $3, $4, $5 }' | awk '{print $4}') )

for KILLID in "${KILLLIST[@]}"
do
  USERNAME=$(ps axo user:20,stat,ppid,pid,comm,args:20 | grep ${KILLID} | awk '$4 == '${KILLID}' { print $1}')
  HOST=$(hostname)
		
		if [ $CARME_MATTERMOST_TRIGGER = "yes" ]; then
    PAYLOAD="payload={\"text\": \" ${HOST}: ghost job with pid $KILLID ($USERNAME)\"}"
    curl -i -X POST --data-urlencode "$PAYLOAD" $CARME_MATTERMOST_WEBHOCK
		fi
		logger "${HOST}: ghost job with pid ${KILLID} (${USERNAME})"
  
		kill $KILLID
		if [ $? -eq 0 ]; then
    sleep 30s
    kill -9 $KILLID
    logger "${HOST}: ghost job with pid ${KILLID} (${USERNAME}) had to be killed using SIGKILL - check what is going on"
		fi
done


KILLLIST=( $(ps axo user:20,stat,ppid,pid,comm | grep -w S | awk '$3 == "1" && !/root|daemon|message|sys|who|nvidia|lightdm|zabbix|munge|kern|statd|ntp/ { printf "%-15s %-5s %-7s %-7s %-7s\n", $1, $2, $3, $4, $5 }' | awk '{print $4}') )

for KILLID in "${KILLLIST[@]}"
do
  USERNAME=$(ps axo user:20,stat,ppid,pid,comm,args:20 | grep ${KILLID} | awk '$4 == '${KILLID}' { print $1}')
		HOST=$(hostname)

		if [ $CARME_MATTERMOST_TRIGGER = "yes" ]; then
    PAYLOAD="payload={\"text\": \" ${HOST}: possible ghost job with pid $KILLID ($USERNAME)\"}"
    curl -i -X POST --data-urlencode "$PAYLOAD" $CARME_MATTERMOST_WEBHOCK
		fi
		logger "${HOST}: possible ghost job with pid ${KILLID} (${USERNAME})"

		kill $KILLID
  if [ $? -eq 0 ]; then
    sleep 30s
    kill -9 $KILLID
    logger "${HOST}: possible ghost job with pid ${KILLID} (${USERNAME}) had to be killed using SIGKILL - check what is going on"
  fi
done


KILLLIST=( $(ps axo user:20,stat,ppid,pid,comm | grep -w R | awk '$3 == "1" && !/root|daemon|message|sys|who|nvidia|lightdm|zabbix|munge|kern|statd|ntp/ { printf "%-15s %-5s %-7s %-7s %-7s\n", $1, $2, $3, $4, $5 }' | awk '{print $4}') ) 

for KILLID in "${KILLLIST[@]}"
do
  USERNAME=$(ps axo user:20,stat,ppid,pid,comm,args:20 | grep ${KILLID} | awk '$4 == '${KILLID}' { print $1}')
  HOST=$(hostname)

		if [ $CARME_MATTERMOST_TRIGGER = "yes" ]; then
    PAYLOAD="payload={\"text\": \" ${HOST}: possible illigal job with pid $KILLID ($USERNAME)\"}"
    curl -i -X POST --data-urlencode "$PAYLOAD" $CARME_MATTERMOST_WEBHOCK
		fi
		logger "${HOST}: possible illigal job with pid ${KILLID} (${USERNAME})"

		kill $KILLID
  if [ $? -eq 0 ]; then
    sleep 30s
    kill -9 $KILLID
    logger "${HOST}: possible illigal job with pid ${KILLID} (${USERNAME}) had to be killed using SIGKILL - check what is going on"
  fi
done

printf "\n"

