#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to chnage the user password to a new value
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
CARME_LDAP_SERVER_IP=$(get_variable CARME_LDAP_SERVER_IP $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_1=$(get_variable CARME_LDAPGROUP_1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_2=$(get_variable CARME_LDAPGROUP_2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_3=$(get_variable CARME_LDAPGROUP_3 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_4=$(get_variable CARME_LDAPGROUP_4 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_5=$(get_variable CARME_LDAPGROUP_5 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_1=$(get_variable CARME_LDAPGROUP_ID_1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_2=$(get_variable CARME_LDAPGROUP_ID_2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_3=$(get_variable CARME_LDAPGROUP_ID_3 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_4=$(get_variable CARME_LDAPGROUP_ID_4 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPGROUP_ID_5=$(get_variable CARME_LDAPGROUP_ID_5 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPINSTANZ_1=$(get_variable CARME_LDAPINSTANZ_1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPINSTANZ_2=$(get_variable CARME_LDAPINSTANZ_2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPINSTANZ_3=$(get_variable CARME_LDAPINSTANZ_3 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPINSTANZ_4=$(get_variable CARME_LDAPINSTANZ_4 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAPINSTANZ_5=$(get_variable CARME_LDAPINSTANZ_5 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_ADMIN=$(get_variable CARME_LDAP_ADMIN $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_DC1=$(get_variable CARME_LDAP_DC1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_DC2=$(get_variable CARME_LDAP_DC2 $CLUSTER_DIR/${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

THIS_NODE_IPS=( $(hostname -I) )
if [[ ! " ${THIS_NODE_IPS[@]} " =~ " ${CARME_LDAP_SERVER_IP} " ]]; then
  printf "${SETCOLOR}this is not the Headnode${NOCOLOR}\n"
  exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------

read -p "Do you want to change a user password? [y/N] " RESP
if [ "$RESP" = "y" ]; then
    printf "\n"

    read -p "enter user name(s) [multiple names separated by space]: " LDAPUSER_HELPER


    #ask for new user password
    read -p "enter the new password [multiple users get the same password]: " LDAP_PASSWD
    if [[ -z "$LDAP_PASSWD" ]]; then
        printf "user password cannot be empty\n"
        exit 137
    fi
    printf "\n"


    #ask for the LDAP admin password
    read -s -p "enter the LDAP admin password: " LDAP_ADMIN_PASSWORD
    if [[ -z "$LDAP_ADMIN_PASSWORD" ]]; then
        printf "LDAP admin password cannot be empty\n"
        exit 137
    fi
    printf "\n"


    for LDAPUSER in $LDAPUSER_HELPER
    do

        if [[ $LDAPUSER =~ [A-Z] ]]; then
            printf "uppercase user-names not allowed\n"
            exit 137
        fi

        if [[ -z "$LDAPUSER" ]]; then
            printf "empty user-names not allowed\n"
            exit 137
        fi

        #get the groupid
        STRING=$(getent passwd | grep $LDAPUSER | awk -F : '$3>h{h=$3;g=$4;u=$1}END{print g ":" u}')
        #printf "$STRING\n\n"
        GROUPID=${STRING%%:*}

        case "$GROUPID" in
            "$CARME_LDAPGROUP_ID_1") LDAPINSTANZ="$CARME_LDAPINSTANZ_1"
                                    LDAPGROUP="$CARME_LDAPGROUP_1"
            ;;
            "$CARME_LDAPGROUP_ID_2") LDAPINSTANZ="$CARME_LDAPINSTANZ_2"
                                    LDAPGROUP="$CARME_LDAPGROUP_2"
            ;;
            "$CARME_LDAPGROUP_ID_3") LDAPINSTANZ="$CARME_LDAPINSTANZ_3"
                                    LDAPGROUP="$CARME_LDAPGROUP_3"
            ;;
            "$CARME_LDAPGROUP_ID_4") LDAPINSTANZ="$CARME_LDAPINSTANZ_4"
                                    LDAPGROUP="$CARME_LDAPGROUP_4"
            ;;
            "$CARME_LDAPGROUP_ID_5") LDAPINSTANZ="$CARME_LDAPINSTANZ_5"
                                    LDAPGROUP="$CARME_LDAPGROUP_5"
            ;;
        esac

        #set new password
        ldappasswd -H ldapi:/// -x -D "cn=$CARME_LDAP_ADMIN,dc=$CARME_LDAP_DC1,dc=$CARME_LDAP_DC2" -w $LDAP_ADMIN_PASSWORD "uid=$LDAPUSER,cn=$LDAPGROUP,ou=$LDAPINSTANZ,dc=$CARME_LDAP_DC1,dc=$CARME_LDAP_DC2" -s $LDAP_PASSWD

        printf "password for $LDAPUSER changed\n"
    done

    exit 0

else
    printf "Bye Bye...\n\n"
    exit 0
fi

