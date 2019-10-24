#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to add a new user to LDAP
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
CARME_LDAP_DEFAULTPASSWD_FOLDER=$(get_variable CARME_LDAP_DEFAULTPASSWD_FOLDER $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_PASSWD_BASESTRING=$(get_variable CARME_LDAP_PASSWD_BASESTRING $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_PASSWD_LENGTH=$(get_variable CARME_LDAP_PASSWD_LENGTH $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_ADMIN=$(get_variable CARME_LDAP_ADMIN $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_DC1=$(get_variable CARME_LDAP_DC1 $CLUSTER_DIR/${CONFIG_FILE})
CARME_LDAP_DC2=$(get_variable CARME_LDAP_DC2 $CLUSTER_DIR/${CONFIG_FILE})
CARME_MATTERMOST_TRIGGER=$(get_variable CARME_MATTERMOST_TRIGGER $CLUSTER_DIR/${CONFIG_FILE})
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

read -p "Do you want to add a new user? [y/N] " RESP
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

    #check if user allready exists
    USEREXISTS=$(id -u $LDAPUSER > /dev/null 2>&1; echo $?)
    if [ "$USEREXISTS" = "0" ]; then
        printf "${SETCOLOR}cannot create${NOCOLOR} $LDAPUSER ${SETCOLOR} --> already exists${NOCOLOR}\n\n"
        exit 137
    fi

    printf "enter GROUPID of new user\n"
    printf "$CARME_LDAPGROUP_1:\t$CARME_LDAPGROUP_ID_1\n"
    printf "$CARME_LDAPGROUP_2:\t$CARME_LDAPGROUP_ID_2\n"
    printf "$CARME_LDAPGROUP_3:\t$CARME_LDAPGROUP_ID_3\n"
    printf "$CARME_LDAPGROUP_4:\t$CARME_LDAPGROUP_ID_4\n"
    printf "$CARME_LDAPGROUP_5:\t$CARME_LDAPGROUP_ID_5\n"
    read GROUPID

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


    #get date and check if default-passwd-folder exists
    LDAP_DATE=`date +%Y-%m-%d`
    LDAP_DATE_END=`date -d "$LDAP_DATE $LDAP_EXPIRE month" +%Y-%m-%d`
    LDAP_FILENAME="new-ldap-user--$LDAP_DATE--$LDAPUSER.txt"
    if [ ! -d $CARME_LDAP_DEFAULTPASSWD_FOLDER ];then
        mkdir $CARME_LDAP_DEFAULTPASSWD_FOLDER
    fi
    LDAP_FILE="$CARME_LDAP_DEFAULTPASSWD_FOLDER/$LDAP_FILENAME"


    #determine highest userid
    LDAP_STRING=$(getent passwd | awk -F : '$3>h{h=$3;u=$1}END{print h ":" u}')
    LDAP_HIGHUSER=${LDAP_STRING#*:}
    LDAP_HIGHUID=${LDAP_STRING%%:*}
    NEXTUID=$((LDAP_HIGHUID+1))


    read -p "expiration time in months [default is 3]: " LDAP_EXPIRE_HELP
    if [[ -z "$LDAP_EXPIRE_HELP" ]]; then
        LDAP_EXPIRE="3"
    else
        LDAP_EXPIRE=$LDAP_EXPIRE_HELP
    fi
    printf "\n"


    #ask for the LDAP admin password
    read -s -p "enter the LDAP admin password: " LDAP_ADMIN_PASSWORD
    if [[ -z "$LDAP_ADMIN_PASSWORD" ]]; then
        printf "LDAP admin password cannot be empty\n"
        exit 137
    fi
    printf "\n"


    # create random password
    LDAP_PASSWD=$(cat /dev/urandom | tr -dc "$CARME_LDAP_PASSWD_BASESTRING" | fold -w $CARME_LDAP_PASSWD_LENGTH | head -n 1)
    echo "default password is:" $LDAP_PASSWD
				printf "\n"


    # step (3): add new user to LDAP database (note do not add whitespaces at the beginning of the next lines!)
ldapadd -v -x -D "cn=$CARME_LDAP_ADMIN,dc=$CARME_LDAP_DC1,dc=$CARME_LDAP_DC2" -w $LDAP_ADMIN_PASSWORD  << EOF
dn:uid=${LDAPUSER},cn=${LDAPGROUP},ou=${LDAPINSTANZ},dc=${CARME_LDAP_DC1},dc=${CARME_LDAP_DC2}
objectClass:top
objectClass:account
objectClass:posixAccount
objectclass:shadowAccount
userid:$LDAPUSER
cn:$LDAPUSER
uidNumber:$NEXTUID
gidNumber:$GROUPID
homeDirectory:/home/$LDAPUSER
loginShell:/bin/bash
EOF

    ldappasswd -D "cn=$CARME_LDAP_ADMIN,dc=$CARME_LDAP_DC1,dc=$CARME_LDAP_DC2" uid=$LDAPUSER,cn=$LDAPGROUP,ou=$LDAPINSTANZ,dc=$CARME_LDAP_DC1,dc=$CARME_LDAP_DC2 -w $LDAP_ADMIN_PASSWORD -s $LDAP_PASSWD


    #pipe new user data to file
    echo "user: $LDAPUSER" >>$LDAP_FILE
    echo "userid: $NEXTUID" >>$LDAP_FILE
    echo "default password: $LDAP_PASSWD" >>$LDAP_FILE
    echo "created: $LDAP_DATE" >>$LDAP_FILE
    echo "expires: $LDAP_DATE_END" >>$LDAP_FILE
    echo "groubid: $GROUPID" >>$LDAP_FILE

    # create home
    mkdir -v /home/$LDAPUSER
    cp -vr /etc/skel/. /home/$LDAPUSER
			 mkdir -v /home/$LDAPUSER/carme_tmp
			 mkdir -v /home/$LDAPUSER/.carme
			 mkdir -v /home/$LDAPUSER/.ssh	
    chown -v -R $NEXTUID:$GROUPID /home/$LDAPUSER


    # add to mattermost
    if [ $CARME_MATTERMOST_TRIGGER = "yes" ]; then
        cd $CARME_MATTERMOST_PATH/bin
        ./$CARME_MATTERMOST_COMMAND user create --email $LDAPUSER@$CARME_MATTERMOST_EMAIL_BASE --username $LDAPUSER --password $LDAP_PASSWD
        ./$CARME_MATTERMOST_COMMAND team add $CARME_MATTERMOST_DEFAULT_TEAM $LDAPUSER@$CARME_MATTERMOST_EMAIL_BASE $LDAPUSER
        cd
    fi


    # reminder
    printf "${SETCOLOR}remember to add $LDAPUSER to the scheduler!${NOCOLOR}\n"

    printf "\n"
else
    printf "Bye Bye...\n\n"
fi

