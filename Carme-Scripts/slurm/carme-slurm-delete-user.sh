#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to add new users to slurm
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------

# default parameters ---------------------------------------------------------------------------------------------------------------
printf "\n"

CLUSTER_DIR="/opt/Carme"
CONFIG_FILE="CarmeConfig"

SETCOLOR='\033[1;33m'
NOCOLOR='\033[0m'
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
CARME_SLURM_ControlAddr=$(get_variable CARME_SLURM_ControlAddr $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_1=$(get_variable CARME_LDAPGROUP_ID_1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_2=$(get_variable CARME_LDAPGROUP_ID_2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_3=$(get_variable CARME_LDAPGROUP_ID_3 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_4=$(get_variable CARME_LDAPGROUP_ID_4 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_5=$(get_variable CARME_LDAPGROUP_ID_5 $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_ClusterName=$(get_variable CARME_SLURM_ClusterName $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_ACCOUNT_1=$(get_variable CARME_SLURM_ACCOUNT_1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_ACCOUNT_2=$(get_variable CARME_SLURM_ACCOUNT_2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_ACCOUNT_3=$(get_variable CARME_SLURM_ACCOUNT_3 $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_ACCOUNT_4=$(get_variable CARME_SLURM_ACCOUNT_4 $CLUSTER_DIR/${CONFIG_FILE})
CARME_SLURM_ACCOUNT_5=$(get_variable CARME_SLURM_ACCOUNT_5 $CLUSTER_DIR/${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

THIS_NODE_IPS=( $(hostname -I) )
if [[ ! " ${THIS_NODE_IPS[@]} " =~ " ${CARME_SLURM_ControlAddr} " ]]; then
  printf "${SETCOLOR}this is not the Headnode${NOCOLOR}\n"
  exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------

read -p "Do you want to delete users from slurm database? [y/N] " RESP
if [ "$RESP" = "y" ]; then

  printf "\n"
  read -p "enter slurm-user(s) that you want to delete [multiple users separated by space]: " SLURMUSER_HELPER
  printf "\n"

  for SLURMUSER in $SLURMUSER_HELPER
  do
      echo $SLURMUSER

      USEREXISTS=$(id -u $SLURMUSER > /dev/null 2>&1; echo $?)
      if [ "$USEREXISTS" = "1" ]; then
          printf "${SETCOLOR}cannot add${NOCOLOR} $SLURMUSER ${SETCOLOR} --> user does not exist${NOCOLOR}\n\n"
          exit 1
      fi

      #-----------------------------------------------------------------------------------------------------------------------------

      STRING=$(getent passwd | grep $SLURMUSER | awk -F : '$3>h{h=$3;g=$4;u=$1}END{print g ":" u}')
      printf "$STRING\n\n"
      SLURMUSERGROUPID=${STRING%%:*}

      if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_1" ]; then
          sacctmgr delete user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_1
      fi

      if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_2" ]; then
          sacctmgr delete user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_2
      fi

      if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_3" ]; then
          sacctmgr delete user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_3
      fi

      if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_4" ]; then
          sacctmgr delete user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_4
      fi

      if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_5" ]; then
          sacctmgr delete user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_5
      fi
  done
else
    printf "Bye Bye...\n\n"
fi

