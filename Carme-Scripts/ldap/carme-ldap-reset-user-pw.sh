#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to reset the user password to a random value
#
# WEBPAGE:   https://carmeteam.github.io/Carme/
# COPYRIGHT: Carme Team @Fraunhofer ITWM
# CONTACT:   dominik.strassel@itwm.fraunhofer.de
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# adjustable parameters ------------------------------------------------------------------------------------------------------------
PATH_TO_SCRIPTS_FOLDER="/opt/Carme/Carme-Scripts"
LDAPUSER_HELPER=( "${@}" )
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
if [[ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ]];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  die "'${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh' not found"
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
check_command hostname
#-----------------------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from config
CARME_LDAP_SERVER_IP=$(get_variable CARME_LDAP_SERVER_IP)
CARME_LDAP_BIND_DN=$(get_variable CARME_LDAP_BIND_DN)
CARME_LDAP_PASSWD_BASESTRING=$(get_variable CARME_LDAP_PASSWD_BASESTRING)
CARME_LDAP_PASSWD_LENGTH=$(get_variable CARME_LDAP_PASSWD_LENGTH)

[[ -z ${CARME_LDAP_SERVER_IP} ]] && die "CARME_LDAP_SERVER_IP not set"
[[ -z ${CARME_LDAP_BIND_DN} ]] && die "CARME_LDAP_BIND_DN not set"
[[ -z ${CARME_LDAP_PASSWD_BASESTRING} ]] && die "CARME_LDAP_PASSWD_BASESTRING not set"
[[ -z ${CARME_LDAP_PASSWD_LENGTH} ]] && die "CARME_LDAP_PASSWD_LENGTH not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if host is the server hosting ldap -----------------------------------------------------------------------------------------
THIS_NODE_IPS=( "$(hostname -I)" )
[[ ! "${THIS_NODE_IPS[*]}" =~ ${CARME_LDAP_SERVER_IP} ]] && die "this is not the server hosting ldap"
#-----------------------------------------------------------------------------------------------------------------------------------



# ask for the LDAP admin password --------------------------------------------------------------------------------------------------
read -s -rp "enter the LDAP admin password: " LDAP_ADMIN_PASSWORD
echo ""
[[ -z "${LDAP_ADMIN_PASSWORD}" ]] && die "LDAP admin password cannot be empty"
#-----------------------------------------------------------------------------------------------------------------------------------


for LDAPUSER in "${LDAPUSER_HELPER[@]}"; do

  # check is username contains uppercase characters --------------------------------------------------------------------------------
  [[ ${LDAPUSER} =~ [A-Z] ]] && die "uppercase user-names not allowed"
  #---------------------------------------------------------------------------------------------------------------------------------


  # check if username is empty -----------------------------------------------------------------------------------------------------
  [[ -z "${LDAPUSER}" ]] && die "empty user-names not allowed"
  #---------------------------------------------------------------------------------------------------------------------------------


  # get LDAP user DN ---------------------------------------------------------------------------------------------------------------
  LDAP_USER_DN="$(ldapsearch -v -x -D "${CARME_LDAP_BIND_DN}" "uid=${LDAPUSER}" -w "${LDAP_ADMIN_PASSWORD}" | grep "dn: uid=${LDAPUSER}" | awk -F'dn: ' '{ print $2 }')"
  [[ -z "${LDAP_USER_DN}" ]] && die "could not determine a valid DN for user '${LDAPUSER}'"
  USER_FOUND_NUMBER=$(echo "${LDAP_USER_DN}" | wc -l)
  [[ "${USER_FOUND_NUMBER}" -gt "1" ]] && die "found more than one possible DN's for user '${LDAPUSER}'"
  #---------------------------------------------------------------------------------------------------------------------------------


  # create random default password -------------------------------------------------------------------------------------------------
  LDAP_PASSWD=$(head /dev/urandom | tr -dc "${CARME_LDAP_PASSWD_BASESTRING}" | head -c "${CARME_LDAP_PASSWD_LENGTH}")
  [[ -z ${LDAP_PASSWD} ]] && die "LDAP_PASSWD not set"
  #---------------------------------------------------------------------------------------------------------------------------------

  # set new password ---------------------------------------------------------------------------------------------------------------
  ldappasswd -H ldapi:/// -x -D "${CARME_LDAP_BIND_DN}" -w "${LDAP_ADMIN_PASSWORD}" "${LDAP_USER_DN}" -s "${LDAP_PASSWD}"
  #---------------------------------------------------------------------------------------------------------------------------------

    echo "password for '${LDAPUSER}' changed to ${LDAP_PASSWD}"
  done
