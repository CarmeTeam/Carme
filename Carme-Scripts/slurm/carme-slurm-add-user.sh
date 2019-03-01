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
    source $CLUSTER_DIR/$CONFIG_FILE
else
    printf "${SETCOLOR}no config-file found in $CLUSTER_DIR${NOCOLOR}\n"
    exit 137
fi

THIS_NODE_IPS=( $(hostname -I) )
if [[ ! " ${THIS_NODE_IPS[@]} " =~ " ${CARME_SLURM_ControlAddr} " ]]; then
    printf "${SETCOLOR}this is not the Headnode${NOCOLOR}\n"
    exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------

read -p "enter ldap-username(s) of new slurm-user(s) [multiple users separated by space] " SLURMUSER_HELPER
printf "\n"

for SLURMUSER in $SLURMUSER_HELPER
do
    echo $SLURMUSER

    USEREXISTS=$(id -u $SLURMUSER > /dev/null 2>&1; echo $?)
    if [ "$USEREXISTS" = "1" ]; then
        printf "${SETCOLOR}cannot add${NOCOLOR} $SLURMUSER ${SETCOLOR} --> user does not exist${NOCOLOR}\n\n"
        exit 1
    fi

    #-------------------------------------------------------------------------------------------------------------------------------

    STRING=$(getent passwd | grep $SLURMUSER | awk -F : '$3>h{h=$3;g=$4;u=$1}END{print g ":" u}')
    printf "$STRING\n\n"
    SLURMUSERGROUPID=${STRING%%:*}

    if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_1" ]; then
        sacctmgr create user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_1 $CARME_SLURM_ACCOUNT_SPECS_1 
    fi

    if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_2" ]; then
        sacctmgr create user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_2 $CARME_SLURM_ACCOUNT_SPECS_2
    fi

    if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_3" ]; then
        sacctmgr create user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_3 $CARME_SLURM_ACCOUNT_SPECS_3
    fi

    if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_4" ]; then
        sacctmgr create user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_4 $CARME_SLURM_ACCOUNT_SPECS_4
    fi

    if [ "$SLURMUSERGROUPID" = "$CARME_LDAPGROUP_ID_5" ]; then
        sacctmgr create user name=$SLURMUSER cluster=$CARME_SLURM_ClusterName account=$CARME_SLURM_ACCOUNT_5 $CARME_SLURM_ACCOUNT_SPECS_5
    fi

    #-------------------------------------------------------------------------------------------------------------------------------

    sacctmgr list associations user=$SLURMUSER
done

scontrol reconfig

exit 0

