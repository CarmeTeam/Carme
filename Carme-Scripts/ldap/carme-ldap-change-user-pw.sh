#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to chnage the user password to a new value
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
check_command awk
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
CARME_LDAP_ADMIN=$(get_variable CARME_LDAP_ADMIN)
CARME_LDAP_DC1=$(get_variable CARME_LDAP_DC1)
CARME_LDAP_DC2=$(get_variable CARME_LDAP_DC2)

[[ -z ${CARME_LDAP_ADMIN} ]] && die "CARME_LDAP_ADMIN not set"
[[ -z ${CARME_LDAP_DC1} ]] && die "CARME_LDAP_DC1 not set"
[[ -z ${CARME_LDAP_DC2} ]] && die "CARME_LDAP_DC2 not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if host is the server hosting ldap -----------------------------------------------------------------------------------------
THIS_NODE_IPS=( "$(hostname -I)" )
[[ ! "${THIS_NODE_IPS[*]}" =~ ${CARME_LDAP_SERVER_IP} ]] && die "this is not the server hosting ldap"
#-----------------------------------------------------------------------------------------------------------------------------------


read -rp "Do you want to change a user password? [y/N] " RESP
echo ""

if [ "$RESP" = "y" ]; then

  read -rp "enter user name(s) [multiple names separated by space]: " LDAPUSER_HELPER
  echo ""

  # ask for new user password ------------------------------------------------------------------------------------------------------
  read -rp "enter the new password [multiple users get the same password]: " LDAP_PASSWD
  echo ""
  [[ -z "${LDAP_PASSWD}" ]] && die "user password cannot be empty"
  #---------------------------------------------------------------------------------------------------------------------------------


  # ask for the LDAP admin password ------------------------------------------------------------------------------------------------
  read -s -rp "enter the LDAP admin password: " LDAP_ADMIN_PASSWORD
  echo ""
  [[ -z "${LDAP_ADMIN_PASSWORD}" ]] && die "LDAP admin password cannot be empty"
  #---------------------------------------------------------------------------------------------------------------------------------


  for LDAPUSER in ${LDAPUSER_HELPER}; do

    # check is username contains uppercase characters ------------------------------------------------------------------------------
    [[ $LDAPUSER =~ [A-Z] ]] && die "uppercase user-names not allowed"
    #-------------------------------------------------------------------------------------------------------------------------------


    # check if username is empty ---------------------------------------------------------------------------------------------------
    [[ -z "$LDAPUSER" ]] && die "empty user-names not allowed"
    #-------------------------------------------------------------------------------------------------------------------------------


    # get id of the users main group -----------------------------------------------------------------------------------------------
    STRING=$(getent passwd | grep "${LDAPUSER}" | awk -F':' '$3>h{h=$3;g=$4;u=$1}END{print g ":" u}')
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
    #-------------------------------------------------------------------------------------------------------------------------------


    # set new password -------------------------------------------------------------------------------------------------------------
    ldappasswd -H ldapi:/// -x -D "cn=${CARME_LDAP_ADMIN},dc=${CARME_LDAP_DC1},dc=${CARME_LDAP_DC2}" -w "${LDAP_ADMIN_PASSWORD}" "uid=${LDAPUSER},cn=${LDAPGROUP},ou=${LDAPINSTANZ},dc=${CARME_LDAP_DC1},dc=${CARME_LDAP_DC2}" -s "${LDAP_PASSWD}"

    echo "password for ${LDAPUSER} changed to ${LDAP_PASSWD}"
  done

else

  echo "Bye Bye..."

fi
