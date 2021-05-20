#!/bin/bash
# ----------------------------------------------------------------------------------------------------------------------------------
# script to create user certificates needed in carme
# ----------------------------------------------------------------------------------------------------------------------------------
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# Contact: info@open-carme.org
# ----------------------------------------------------------------------------------------------------------------------------------


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
  die "ERROR: carme-basic-bash-functions.sh not found but needed"
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
check_command openssl
#-----------------------------------------------------------------------------------------------------------------------------------


# get needed variables from config file --------------------------------------------------------------------------------------------
CARME_SSL_C=$(get_variable CARME_SSL_C)
CARME_SSL_ST=$(get_variable CARME_SSL_ST)
CARME_SSL_L=$(get_variable CARME_SSL_L)
CARME_SSL_O=$(get_variable CARME_SSL_O)
CARME_SSL_OU=$(get_variable CARME_SSL_OU)
CARME_SSL_EMAIL_BASE=$(get_variable CARME_SSL_EMAIL_BASE)

[[ -z ${CARME_SSL_C} ]] && die "CARME_SSL_C not set"
[[ -z ${CARME_SSL_ST} ]] && die "CARME_SSL_ST not set"
[[ -z ${CARME_SSL_L} ]] && die "CARME_SSL_L not set"
[[ -z ${CARME_SSL_O} ]] && die "CARME_SSL_O not set"
[[ -z ${CARME_SSL_OU} ]] && die "CARME_SSL_OU not set"
[[ -z ${CARME_SSL_EMAIL_BASE} ]] && die "CARME_SSL_EMAIL_BASE not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# define backend cert and key file -------------------------------------------------------------------------------------------------
PATH_TO_BACKEND_CERT_AND_KEY="/opt/Carme/Carme-Backend/SSL"
BACKEND_CERT="${PATH_TO_BACKEND_CERT_AND_KEY}/backend.crt"
BACKEND_KEY="${PATH_TO_BACKEND_CERT_AND_KEY}/backend.key"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if backend cert exists -----------------------------------------------------------------------------------------------------
[[ ! -f ${BACKEND_CERT} && ! -f ${BACKEND_KEY} ]] && die "backend.crt and backend.key have to be in '${PATH_TO_BACKEND_CERT_AND_KEY}'"
#-----------------------------------------------------------------------------------------------------------------------------------


read -rp "Do you want to create a new user certificate (validity 10 years)? [y/N] " RESP
echo ""

if [ "${RESP}" = "y" ]; then

  read -rp "enter ldap-username(s) of users that need a new certificate [multiple users separated by space] " CLUSTER_USER_HELPER
  echo ""

  for CLUSTER_USER in ${CLUSTER_USER_HELPER}; do

    # determine user group ---------------------------------------------------------------------------------------------------------
    CLUSTER_USER_GROUP=$(id -gn "$CLUSTER_USER")
    [[ -z ${CLUSTER_USER_GROUP} ]] && die "CLUSTER_USER_GROUP not set"
    #-------------------------------------------------------------------------------------------------------------------------------

    # determine user home ----------------------------------------------------------------------------------------------------------
    USER_HOME=$(getent passwd "${CLUSTER_USER}" | cut -d: -f6)
    [[ -z ${USER_HOME} ]] && die "USER_HOME not set"
    #-------------------------------------------------------------------------------------------------------------------------------


    # check for config and cert folder ---------------------------------------------------------------------------------------------
    USER_CONFIG_FOLDER="${USER_HOME}/.config"
    if [ ! -d "${USER_CONFIG_FOLDER}" ];then
      mkdir "${USER_CONFIG_FOLDER}"
      chown -R "${CLUSTER_USER}":"${CLUSTER_USER_GROUP}" "${USER_CONFIG_FOLDER}"
    fi

    CERT_STORE="${USER_CONFIG_FOLDER}/carme"
    if [ ! -d "${CERT_STORE}" ];then
      mkdir "${CERT_STORE}"
      chown -R "${CLUSTER_USER}":"${CLUSTER_USER_GROUP}" "${CERT_STORE}"
    fi
    #-------------------------------------------------------------------------------------------------------------------------------


    # create new user keys ---------------------------------------------------------------------------------------------------------
    USER_KEY="${CERT_STORE}/${CLUSTER_USER}.key"
    USER_CSR="${CERT_STORE}/${CLUSTER_USER}.csr"
    USER_CRT="${CERT_STORE}/${CLUSTER_USER}.crt"

    KEY_BIT="4096"
    VALIDATION_TIME="3652"

    # create user key file
    openssl genrsa -out "${USER_KEY}" ${KEY_BIT}

    # create user csr file
    openssl req -new -key "${USER_KEY}" -out "${USER_CSR}" -days ${VALIDATION_TIME} -subj "/C=${CARME_SSL_C}/ST=${CARME_SSL_ST}/L=${CARME_SSL_L}/O=${CARME_SSL_O}/OU=${CARME_SSL_OU}/CN=${CLUSTER_USER}/emailAddress=${CLUSTER_USER}${CARME_SSL_EMAIL_BASE}" -passin pass:""

    # create user crt file
    openssl x509 -req -days ${VALIDATION_TIME} -in "${USER_CSR}" -CA ${BACKEND_CERT} -CAkey ${BACKEND_KEY} -set_serial 01 -out "${USER_CRT}"
    #-------------------------------------------------------------------------------------------------------------------------------


    # change ownership of new certificates ---------------------------------------------------------------------------------------------
    [[ -f "${USER_CSR}" ]] && rm "${USER_CSR}"
    chown "${CLUSTER_USER}":"${CLUSTER_USER_GROUP}" "${USER_CRT}"
    chown "${CLUSTER_USER}":"${CLUSTER_USER_GROUP}" "${USER_KEY}"
    #-----------------------------------------------------------------------------------------------------------------------------------

  done

else

  echo "Bye Bye..."

fi

exit 0
