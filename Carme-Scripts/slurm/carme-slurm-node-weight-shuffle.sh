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
# variables from config
CARME_SLURM_ControlAddr=$(get_variable CARME_SLURM_ControlAddr $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_CONFIG_FILE=$(get_variable CARME_SLURM_CONFIG_FILE $CLUSTER_DIR/${CONFIG_FILE})
CARME_NODES_LIST=$(get_variable CARME_NODES_LIST $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_BackupController=$(get_variable CARME_SLURM_BackupController $CLUSTER_DIR/${CONFIG_FILE})
CARME_COMPUTENODES_1=$(get_variable CARME_COMPUTENODES_1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_BUILDNODE_1=$(get_variable CARME_BUILDNODE_1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_COMPUTENODES_CONFIG_1=$(get_variable CARME_SLURM_COMPUTENODES_CONFIG_1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_COMPUTENODES_2=$(get_variable CARME_COMPUTENODES_2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_COMPUTENODES_LIST_2=$(get_variable CARME_COMPUTENODES_LIST_2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_BUILDNODE_2=$(get_variable CARME_BUILDNODE_2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_COMPUTENODES_CONFIG_2=$(get_variable CARME_SLURM_COMPUTENODES_CONFIG_2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_COMPUTENODES_3=$(get_variable CARME_COMPUTENODES_3 $CLUSTER_DIR/${CONFIG_FILE})
CARME_COMPUTENODES_LIST_3=$(get_variable CARME_COMPUTENODES_LIST_3 $CLUSTER_DIR/${CONFIG_FILE})
CARME_BUILDNODE_3=$(get_variable CARME_BUILDNODE_3 $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_COMPUTENODES_CONFIG_3=$(get_variable CARME_SLURM_COMPUTENODES_CONFIG_3 $CLUSTER_DIR/${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

THIS_NODE_IPS=( $(hostname -I) )
if [[ ! " ${THIS_NODE_IPS[@]} " =~ " ${CARME_SLURM_ControlAddr} " ]]; then
  printf "${SETCOLOR}this is not the Headnode${NOCOLOR}\n"
  exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------

read -p "Do you want to shuffle the weights of the compute nodes? [y/N] " RESP
if [ "$RESP" = "y" ]; then
    printf "\n"

    # nodes config number 1
    for NODES in $CARME_COMPUTENODES_1; do
      if [ $NODES = $CARME_BUILDNODE_1 ];then
        RAND=$(( $RANDOM % 1000 + 701 ))
      else
        RAND=$(( $RANDOM % 500 + 1 ))
      fi
      sed -i '/NodeName='"${NODES}"'/c\NodeName='"${NODES}"' '"${CARME_SLURM_COMPUTENODES_CONFIG_1}"' Weight='"${RAND}" $CARME_SLURM_CONFIG_FILE
    done


    # nodes config number 2
				if [[ ! -z "$CARME_COMPUTENODES_2" ]]; then
      for NODES in $CARME_COMPUTENODES_LIST_2; do
        if [ $NODES = $CARME_BUILDNODE_2 ];then
          RAND=$(( $RANDOM % 1000 + 701 ))
        else
          RAND=$(( $RANDOM % 500 + 1 ))
        fi
        sed -i '/NodeName='"${NODES}"'/c\NodeName='"${NODES}"' '"${CARME_SLURM_COMPUTENODES_CONFIG_2}"' Weight='"${RAND}" $CARME_SLURM_CONFIG_FILE
      done
				fi


    # nodes config number 3
    if [[ ! -z "$CARME_COMPUTENODES_3" ]]; then
      for NODES in $CARME_COMPUTENODES_LIST_3; do
        if [ $NODES = $CARME_BUILDNODE_3 ];then
          RAND=$(( $RANDOM % 1000 + 701 ))
        else
          RAND=$(( $RANDOM % 500 + 1 ))
        fi
        sed -i '/NodeName='"${NODES}"'/c\NodeName='"${NODES}"' '"${CARME_SLURM_COMPUTENODES_CONFIG_3}"' Weight='"${RAND}" $CARME_SLURM_CONFIG_FILE
      done
    fi


    for HOSTS in $CARME_NODES_LIST; do
        printf "\n--------------------\n"
        printf "${HOSTS}\n"
        scp $CARME_SLURM_CONFIG_FILE ${HOSTS}:$CARME_SLURM_CONFIG_FILE
    done


    if [[ ! -z "$CARME_SLURM_BackupController" ]]; then
        scp $CARME_SLURM_CONFIG_FILE $CARME_SLURM_BackupController:$CARME_SLURM_CONFIG_FILE
    fi

    scontrol reconfig

    printf "\n"
else
    printf "Bye Bye...\n\n"
fi

