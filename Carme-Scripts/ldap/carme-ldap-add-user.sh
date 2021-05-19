#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to add a new user to LDAP
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
PATH_TO_SCRIPTS_FOLDER="/opt/Carme/Carme-Scripts"
if [ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  die "carme-basic-bash-functions.sh not found but needed"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# some basic checks before we continue ---------------------------------------------------------------------------------------------
# check if bash is used to execute the script
is_bash

# check if root executes this script
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command grep
check_command getent
check_command ldapadd
check_command ldappasswd
#-----------------------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from config
CARME_LDAP_SERVER_IP=$(get_variable CARME_LDAP_SERVER_IP)
CARME_LDAPGROUP_1=$(get_variable CARME_LDAPGROUP_1)
CARME_LDAPGROUP_2=$(get_variable CARME_LDAPGROUP_2)
CARME_LDAPGROUP_3=$(get_variable CARME_LDAPGROUP_3)
CARME_LDAPGROUP_4=$(get_variable CARME_LDAPGROUP_4)
CARME_LDAPGROUP_5=$(get_variable CARME_LDAPGROUP_5)
CARME_LDAPGROUP_ID_1=$(get_variable CARME_LDAPGROUP_ID_1)
CARME_LDAPGROUP_ID_2=$(get_variable CARME_LDAPGROUP_ID_2)
CARME_LDAPGROUP_ID_3=$(get_variable CARME_LDAPGROUP_ID_3)
CARME_LDAPGROUP_ID_4=$(get_variable CARME_LDAPGROUP_ID_4)
CARME_LDAPGROUP_ID_5=$(get_variable CARME_LDAPGROUP_ID_5)
CARME_LDAPINSTANZ_1=$(get_variable CARME_LDAPINSTANZ_1)
CARME_LDAPINSTANZ_2=$(get_variable CARME_LDAPINSTANZ_2)
CARME_LDAPINSTANZ_3=$(get_variable CARME_LDAPINSTANZ_3)
CARME_LDAPINSTANZ_4=$(get_variable CARME_LDAPINSTANZ_4)
CARME_LDAPINSTANZ_5=$(get_variable CARME_LDAPINSTANZ_5)
CARME_LDAP_DEFAULTPASSWD_FOLDER=$(get_variable CARME_LDAP_DEFAULTPASSWD_FOLDER)
CARME_LDAP_PASSWD_BASESTRING=$(get_variable CARME_LDAP_PASSWD_BASESTRING)
CARME_LDAP_PASSWD_LENGTH=$(get_variable CARME_LDAP_PASSWD_LENGTH)
CARME_LDAP_ADMIN=$(get_variable CARME_LDAP_ADMIN)
CARME_LDAP_DC1=$(get_variable CARME_LDAP_DC1)
CARME_LDAP_DC2=$(get_variable CARME_LDAP_DC2)
#-----------------------------------------------------------------------------------------------------------------------------------


# check if host is the server hosting ldap -----------------------------------------------------------------------------------------
THIS_NODE_IPS=( "$(hostname -I)" )
[[ ! "${THIS_NODE_IPS[*]}" =~ ${CARME_LDAP_SERVER_IP} ]] && die "this is not the server hosting ldap"
#-----------------------------------------------------------------------------------------------------------------------------------


read -rp "Do you want to add a new user? [y/N] " RESP
echo ""

if [ "$RESP" = "y" ];then

  read -rp "enter new user name: " LDAPUSER

  # check is username contains uppercase characters --------------------------------------------------------------------------------
  [[ $LDAPUSER =~ [A-Z] ]] && die "uppercase usernames are not allowed"
  #---------------------------------------------------------------------------------------------------------------------------------


  # check if username is empty -----------------------------------------------------------------------------------------------------
  [[ -z "$LDAPUSER" ]] && die "empty usernames are not allowed"
  #---------------------------------------------------------------------------------------------------------------------------------


  # check if user allready exists --------------------------------------------------------------------------------------------------
  USEREXISTS=$(id -u "${LDAPUSER}" > /dev/null 2>&1; echo $?)
  [[ "${USEREXISTS}" = "0" ]] && die "cannot create ${LDAPUSER} as it already exists"
  #---------------------------------------------------------------------------------------------------------------------------------


  # define ldap instance and group -------------------------------------------------------------------------------------------------
  echo "enter GROUPID of new user"
  echo -e "$CARME_LDAPGROUP_1:\t$CARME_LDAPGROUP_ID_1\n"
  echo -e "$CARME_LDAPGROUP_2:\t$CARME_LDAPGROUP_ID_2\n"
  echo -e "$CARME_LDAPGROUP_3:\t$CARME_LDAPGROUP_ID_3\n"
  echo -e "$CARME_LDAPGROUP_4:\t$CARME_LDAPGROUP_ID_4\n"
  echo -e "$CARME_LDAPGROUP_5:\t$CARME_LDAPGROUP_ID_5\n"

  read -r GROUPID

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
  #---------------------------------------------------------------------------------------------------------------------------------


  # get date and check if default-passwd-folder exists -----------------------------------------------------------------------------
  LDAP_DATE="$(date +%Y-%m-%d)"
  LDAP_DATE_END="$(date -d "${LDAP_DATE} ${LDAP_EXPIRE} month" +%Y-%m-%d)"
  LDAP_FILENAME="new-ldap-user--$LDAP_DATE--$LDAPUSER.txt"

  [[ -z ${CARME_LDAP_DEFAULTPASSWD_FOLDER} ]] && die "CARME_LDAP_DEFAULTPASSWD_FOLDER not set"
  if [ ! -d "${CARME_LDAP_DEFAULTPASSWD_FOLDER}" ];then
    mkdir "${CARME_LDAP_DEFAULTPASSWD_FOLDER}" || die "cannot create ${CARME_LDAP_DEFAULTPASSWD_FOLDER}"
  fi
  #---------------------------------------------------------------------------------------------------------------------------------


  # determine highest userid and set user-id ---------------------------------------------------------------------------------------
  LDAP_STRING=$(getent passwd | awk -F : '$3>h{h=$3;u=$1}END{print h ":" u}')
  LDAP_HIGHUID=${LDAP_STRING%%:*}
  NEXTUID=$((LDAP_HIGHUID+1))
  #---------------------------------------------------------------------------------------------------------------------------------


  # define expiration time ---------------------------------------------------------------------------------------------------------
  # NOTE: this is defined in order to have an overview over the users. They are not aitomatically deleted after that time
  read -rp "expiration time in months [default is 3]: " LDAP_EXPIRE_HELP
  echo ""
  if [[ -z "${LDAP_EXPIRE_HELP}" ]];then
    LDAP_EXPIRE="3"
  else
    LDAP_EXPIRE="${LDAP_EXPIRE_HELP}"
  fi
  #---------------------------------------------------------------------------------------------------------------------------------


  # ask for the LDAP admin password ------------------------------------------------------------------------------------------------
  read -s -rp "enter the LDAP admin password: " LDAP_ADMIN_PASSWORD
  echo ""
  [[ -z "${LDAP_ADMIN_PASSWORD}" ]] && die "LDAP admin password cannot be empty"
  #---------------------------------------------------------------------------------------------------------------------------------


  # create random default password -------------------------------------------------------------------------------------------------
  LDAP_PASSWD=$(head /dev/urandom | tr -dc "${CARME_LDAP_PASSWD_BASESTRING}" | head -c "${CARME_LDAP_PASSWD_LENGTH}")
  [[ -z ${LDAP_PASSWD} ]] && die "LDAP_PASSWD not set"
  echo "default password is: ${LDAP_PASSWD}"
  echo ""
  #---------------------------------------------------------------------------------------------------------------------------------


  # add new user to LDAP database --------------------------------------------------------------------------------------------------
ldapadd -v -x -D "cn=${CARME_LDAP_ADMIN},dc=${CARME_LDAP_DC1},dc=${CARME_LDAP_DC2}" -w "${LDAP_ADMIN_PASSWORD}"  << EOF
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

  ldappasswd -D "cn=${CARME_LDAP_ADMIN},dc=${CARME_LDAP_DC1},dc=${CARME_LDAP_DC2}" uid="${LDAPUSER}",cn="${LDAPGROUP}",ou="${LDAPINSTANZ}",dc="${CARME_LDAP_DC1}",dc="${CARME_LDAP_DC2}" -w "${LDAP_ADMIN_PASSWORD}" -s "${LDAP_PASSWD}"
  #---------------------------------------------------------------------------------------------------------------------------------


  # pipe new user data to file -----------------------------------------------------------------------------------------------------
  echo "user: ${LDAPUSER}
userid: ${NEXTUID}
default password: ${LDAP_PASSWD}
created: ${LDAP_DATE}
expires: ${LDAP_DATE_END}
groubid: ${GROUPID}
" >> "${CARME_LDAP_DEFAULTPASSWD_FOLDER}/${LDAP_FILENAME}"
  #---------------------------------------------------------------------------------------------------------------------------------


  # create user home ---------------------------------------------------------------------------------------------------------------
  mkdir -v "/home/${LDAPUSER}" || die "cannot create /home/${LDAPUSER}"
  cp -vr "/etc/skel/." "/home/${LDAPUSER}" || die "cannot copy /etc/skel/. to /home/${LDAPUSER}"
  mkdir -vp "/home/${LDAPUSER}/.config/carme" || die "cannot create /home/${LDAPUSER}/.config/carme"
  mkdir -vp "/home/${LDAPUSER}/.local/share/carme" || die "cannot create /home/${LDAPUSER}/.local/share/carme"
  mkdir -vp "/home/${LDAPUSER}/.ssh" || die "cannot create /home/${LDAPUSER}/.ssh"
  chown -v -R "${NEXTUID}":"${GROUPID}" "/home/${LDAPUSER}" || die "cannot change ownership of /home/${LDAPUSER}"
  #---------------------------------------------------------------------------------------------------------------------------------


  # note ---------------------------------------------------------------------------------------------------------------------------
  echo "user credentials are stored in"
  echo "${CARME_LDAP_DEFAULTPASSWD_FOLDER}/${LDAP_FILENAME}"
  echo ""
  #---------------------------------------------------------------------------------------------------------------------------------


  # reminder -----------------------------------------------------------------------------------------------------------------------
  echo "remember to"
  echo "           - add ${LDAPUSER} to the scheduler"
  echo "           - create a user certificate for ${LDAPUSER}"
  #---------------------------------------------------------------------------------------------------------------------------------

else

  echo "Bye Bye..."

fi
