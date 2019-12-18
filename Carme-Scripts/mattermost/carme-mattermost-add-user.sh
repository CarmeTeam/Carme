# script to add a new user to mattermost
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

if [ -f "${CLUSTER_DIR}/${CONFIG_FILE}" ]; then
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
CARME_LDAP_SERVER_IP=$(get_variable CARME_LDAP_SERVER_IP $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_DEFAULTPASSWD_FOLDER=$(get_variable CARME_LDAP_DEFAULTPASSWD_FOLDER $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_PASSWD_BASESTRING=$(get_variable CARME_LDAP_PASSWD_BASESTRING $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_PASSWD_LENGTH=$(get_variable CARME_LDAP_PASSWD_LENGTH $CLUSTER_DIR/${CONFIG_FILE})
CARME_MATTERMOST_PATH=$(get_variable CARME_MATTERMOST_PATH $CLUSTER_DIR/${CONFIG_FILE})
CARME_MATTERMOST_COMMAND=$(get_variable CARME_MATTERMOST_COMMAND $CLUSTER_DIR/${CONFIG_FILE})
CARME_MATTERMOST_EMAIL_BASE=$(get_variable CARME_MATTERMOST_EMAIL_BASE $CLUSTER_DIR/${CONFIG_FILE})
CARME_MATTERMOST_DEFAULT_TEAM=$(get_variable CARME_MATTERMOST_DEFAULT_TEAM $CLUSTER_DIR/${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

THIS_NODE_IPS=( $(hostname -I) )
if [[ ! " ${THIS_NODE_IPS[@]} " =~ " ${CARME_LDAP_SERVER_IP} " ]]; then
  printf "${SETCOLOR}this is not the Headnode${NOCOLOR}\n"
  exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------

read -p "Do you want to add a new user to mattermost? [y/N] " RESP
if [ "$RESP" = "y" ]; then
    printf "\n"

    read -p "enter new user name: " LDAPUSER

    if [[ $LDAPUSER =~ [A-Z] ]]; then
        printf "uppercase user-names not allowed\n"
        exit 137
    fi

    if [[ -z "$LDAPUSER" ]]; then
        printf "empty user-names not allowed\n"
        exit 137
    fi

    #get date and check if default-passwd-folder exists
    LDAP_DATE=`date +%Y-%m-%d`
    LDAP_FILENAME="new-mattermost-user--$DATE--$LDAPUSER.txt"
    if [ ! -d $CARME_LDAP_DEFAULTPASSWD_FOLDER ];then
        mkdir $CARME_LDAP_DEFAULTPASSWD_FOLDER
    fi
    LDAP_FILE="$CARME_LDAP_DEFAULTPASSWD_FOLDER/$LDAP_FILENAME"


    # create random password
    LDAP_PASSWD=$(cat /dev/urandom | tr -dc "$CARME_LDAP_PASSWD_BASESTRING" | fold -w $CARME_LDAP_PASSWD_LENGTH | head -n 1)
    printf "default password is:\t $LDAP_PASSWD\n"


    # add to mattermost
    cd $CARME_MATTERMOST_PATH/bin
    ./$CARME_MATTERMOST_COMMAND user create --email $LDAPUSER@$CARME_MATTERMOST_EMAIL_BASE --username $LDAPUSER --password $LDAP_PASSWD
    ./$CARME_MATTERMOST_COMMAND team add $CARME_MATTERMOST_DEFAULT_TEAM $LDAPUSER@$CARME_MATTERMOST_EMAIL_BASE $LDAPUSER
    cd

    printf "\n"
else
    printf "Bye Bye...\n\n"
fi

