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


# check if backend cert exists -----------------------------------------------------------------------------------------------------
if [[ ! -f backend.crt && ! -f backend.key ]]; then
  die "ERROR: backend.crt and backend.key have to be in this directory"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


read -rp "Do you want to create a new user certificate (validity 10 years)? [y/N] " RESP
echo ""

if [ "${RESP}" = "y" ]; then

  read -rp "enter ldap-username(s) of users that need a new certificate [multiple users separated by space] " CLUSTER_USER_HELPER
  echo ""

  for CLUSTER_USER in ${CLUSTER_USER_HELPER}; do

    # determine user group ---------------------------------------------------------------------------------------------------------
    CLUSTER_USER_GROUP=$(id -gn "$CLUSTER_USER")
    if [[ -z ${CLUSTER_USER_GROUP} ]];then
      die "CLUSTER_USER_GROUP not set"
    fi
    #-------------------------------------------------------------------------------------------------------------------------------


    # create new user keys ---------------------------------------------------------------------------------------------------------
    echo "creating certs for ${CLUSTER_USER}:${CLUSTER_USER_GROUP}"

    openssl genrsa -out "${CLUSTER_USER}.key" 4096

    openssl req -new -key "${CLUSTER_USER}.key" -out "${CLUSTER_USER}.csr" -days 3652 -subj "/C=$CARME_SSL_C/ST=$CARME_SSL_ST/L=$CARME_SSL_L/O=$CARME_SSL_O/OU=${CARME_SSL_OU}/CN=${CLUSTER_USER}/emailAddress=${CLUSTER_USER}${CARME_SSL_EMAIL_BASE}" -passin pass:"" 

    openssl x509 -req -days 3652 -in "${CLUSTER_USER}.csr" -CA backend.crt -CAkey backend.key -set_serial 01 -out "${CLUSTER_USER}.crt"
    #-------------------------------------------------------------------------------------------------------------------------------


    # change ownership of new certificates -----------------------------------------------------------------------------------------
    chown "${CLUSTER_USER}":"${CLUSTER_USER_GROUP}" "${CLUSTER_USER}.crt"
    chown "${CLUSTER_USER}":"${CLUSTER_USER_GROUP}" "${CLUSTER_USER}.csr"
    chown "${CLUSTER_USER}":"${CLUSTER_USER_GROUP}" "${CLUSTER_USER}.key"
    #-------------------------------------------------------------------------------------------------------------------------------


    # move new certificates to /home/$USER/.config/carme ---------------------------------------------------------------------------
    USER_HOME=$(getent passwd "${CLUSTER_USER}" | cut -d: -f6)
    if [[ -z ${USER_HOME} ]];then
      die "USER_HOME not set"
    fi

    CERT_STORE="${USER_HOME}/.config/carme"
    if [ ! -d "${CERT_STORE}" ]; then
      mkdir "${CERT_STORE}"
    fi

    echo "move new user certs to ${USER_HOME}/.config/carme"
    mv -v "${CLUSTER_USER}.crt" "${CERT_STORE}/${CLUSTER_USER}.crt"
    mv -v "${CLUSTER_USER}.csr" "${CERT_STORE}/${CLUSTER_USER}.csr"
    mv -v "${CLUSTER_USER}.key" "${CERT_STORE}/${CLUSTER_USER}.key"
    #-------------------------------------------------------------------------------------------------------------------------------
  done

else

  echo "Bye Bye..."

fi
