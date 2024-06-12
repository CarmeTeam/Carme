#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Script to create the certificates for the backend, frontend and the communiaction with the slurmctld.
#
# WEBPAGE:   https://carmeteam.github.io/Carme/
# COPYRIGHT: Carme Team @Fraunhofer ITWM
# CONTACT:   dominik.strassel@itwm.fraunhofer.de
#-----------------------------------------------------------------------------------------------------------------------------------


# bash set buildins ----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# variables ------------------------------------------------------------------------------------------------------------------------
CARME_PATH="/opt/Carme"                                                                  # path to carme installation
PATH_TO_SCRIPTS_FOLDER="${CARME_PATH}/Carme-Scripts"                                     # path to the carme scripts folder
CARME_FRONTEND_SSL_PATH="${CARME_FRONTEND_PATH}/Carme-Django/webfrontend/SSL"            # path to store the frontend certs

BACKEND_CERT="${CARME_BACKEND_PATH}/SSL/backend.crt"                                     # full backend cert name
BACKEND_KEY="${CARME_BACKEND_PATH}/SSL/backend.key"                                      # full backend key name

FRONTEND_CERT="${CARME_FRONTEND_SSL_PATH}/frontend.crt"                                  # full frontend cert name
FRONTEND_KEY="${CARME_FRONTEND_SSL_PATH}/frontend.key"                                   # full frontend key name

SLURMCTLD_CERT="${PATH_TO_SCRIPTS_FOLDER}/backend/slurmctld.crt"                         # full slurmctld cert name
SLURMCTLD_KEY="${PATH_TO_SCRIPTS_FOLDER}/backend/slurmctld.key"                          # full slurmctld key name

BIT_RATE="4096"                                                                          # bits to use for key
CERT_DAYS="3650"                                                                         # key validation in days
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


# check if bash is used to execute the script --------------------------------------------------------------------------------------
is_bash
#-----------------------------------------------------------------------------------------------------------------------------------


# check if root executes this script
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command openssl
#-----------------------------------------------------------------------------------------------------------------------------------


# import needed variables from CarmeConfig -----------------------------------------------------------------------------------------
CARME_BACKEND_PATH=$(get_variable CARME_BACKEND_PATH)
CARME_FRONTEND_PATH=$(get_variable CARME_FRONTEND_PATH)
CARME_HEADNODE_NAME=$(get_variable CARME_HEADNODE_NAME)
CARME_SSL_C=$(get_variable CARME_SSL_C)
CARME_SSL_ST=$(get_variable CARME_SSL_ST)
CARME_SSL_L=$(get_variable CARME_SSL_L)
CARME_SSL_O=$(get_variable CARME_SSL_O)
CARME_SSL_OU=$(get_variable CARME_SSL_OU)
CARME_SSL_EMAIL_BASE=$(get_variable CARME_SSL_EMAIL_BASE)

[[ -z ${CARME_BACKEND_PATH} ]] && die "CARME_BACKEND_PATH not set"
[[ -z ${CARME_FRONTEND_PATH} ]] && die "CARME_FRONTEND_PATH not set"
[[ -z ${CARME_HEADNODE_NAME} ]] && die "CARME_HEADNODE_NAME not set"
[[ -z ${CARME_SSL_C} ]] && die "CARME_SSL_C not set"
[[ -z ${CARME_SSL_ST} ]] && die "CARME_SSL_ST not set"
[[ -z ${CARME_SSL_L} ]] && die "CARME_SSL_L not set"
[[ -z ${CARME_SSL_O} ]] && die "CARME_SSL_O not set"
[[ -z ${CARME_SSL_OU} ]] && die "CARME_SSL_OU not set"
[[ -z ${CARME_SSL_EMAIL_BASE} ]] && die "CARME_SSL_EMAIL_BASE not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if node is headnode --------------------------------------------------------------------------------------------------------
[[ "$(hostname -s)" != "${CARME_HEADNODE_NAME}" ]] && die "This is not the headnode (${CARME_HEADNODE_NAME}) defined in your CARME config."
#-----------------------------------------------------------------------------------------------------------------------------------


# define functions -----------------------------------------------------------------------------------------------------------------

function check_for_wwwdata () {
# check if www-data user and group exist

  if id -u www-data &>/dev/null;then
    WWW_DATA_USER="true"
  else
    WWW_DATA_USER="false"
  fi

  if id -g www-data &>/dev/null;then
    WWW_DATA_GROUP="true"
  else
    WWW_DATA_GROUP="false"
  fi
}


function create_backend_certs () {
# function to create the backend certs to authenticate and encrypt communication between the jobs, the frontend and the backend

  openssl genrsa -out "/tmp/backend.key" "${BIT_RATE}"

  openssl req -new -x509 -days "${CERT_DAYS}" -key "/tmp/backend.key" -out "/tmp/backend.crt"

  chmod 600 "/tmp/backend.key"
  chmod 600 "/tmp/backend.crt"

  [[ -f "${BACKEND_KEY}" ]] && mv "${BACKEND_KEY}" "${BACKEND_KEY}.bak"
  if [[ -f "${BACKEND_CERT}" ]];then
    mv "${BACKEND_CERT}" "${BACKEND_CERT}.bak"

    echo "WARNING: You created new backend certificates. Keep in mind that user"
    echo "certificates created with the old backend certificates are no longer"
    echo "valid."
  fi

  mv "/tmp/backend.key" "${BACKEND_KEY}" || die "cannot move '/tmp/backend.key' to '${BACKEND_KEY}'"
  mv "/tmp/backend.crt" "${BACKEND_CERT}" || die "cannot move '/tmp/backend.crt' to '${BACKEND_CERT}'"
}


function create_frontend_certs () {
# create the certs for the carme frontend.
# NOTE: needs the output from create_backend_certs

  openssl genrsa -out "/tmp/frontend.key" "${BIT_RATE}"

  openssl req -new -key "/tmp/frontend.key" -out frontend.csr -subj "/C=${CARME_SSL_C}/ST=${CARME_SSL_ST}/L=${CARME_SSL_L}/O=${CARME_SSL_O}/OU=${CARME_SSL_OU}/CN=carme/emailAddress=frontend@${CARME_SSL_EMAIL_BASE}" -passin pass:""

  openssl x509 -req -days "${CERT_DAYS}" -in "/tmp/frontend.csr" -CA "${BACKEND_CERT}" -CAkey "${BACKEND_KEY}" -set_serial 01 -out "/tmp/frontend.crt"

  rm "/tmp/frontend.csr" || die "cannot remove '/tmp/frontend.csr'"

  if [[ "${WWW_DATA_USER}" == "true" && "${WWW_DATA_GROUP}" == "true" ]];then
    chown www-data:www-data "/tmp/frontend.key"
    chown www-data:www-data "/tmp/frontend.crt"
  fi

  mkdir -p "${CARME_FRONTEND_SSL_PATH}" || die "cannot create '${CARME_FRONTEND_SSL_PATH}'"

  [[ -f "${FRONTEND_KEY}" ]] && mv "${FRONTEND_KEY}" "${FRONTEND_KEY}.bak"
  [[ -f "${FRONTEND_CERT}" ]] && mv "${FRONTEND_CERT}" "${FRONTEND_CERT}.bak"
  mv "/tmp/frontend.key" "${FRONTEND_KEY}" || die "cannot move '/tmp/frontend.key' to '${FRONTEND_KEY}'"
  mv "/tmp/frontend.crt" "${FRONTEND_CERT}" || die "cannot move '/tmp/frontend.crt' to '${FRONTEND_CERT}'"
}


function create_slurmctld_certs () {
# cert for the callbacks of the slurmctld.
# NOTE: needs the output from create_backend_certs

  openssl genrsa -out "/tmp/slurmctld.key" "${BIT_RATE}"

  openssl req -new -key "/tmp/slurmctld.key" -out "/tmp/slurmctld.csr" -subj "/C=${CARME_SSL_C}/ST=${CARME_SSL_ST}/L=${CARME_SSL_L}/O=${CARME_SSL_O}/OU=${CARME_SSL_OU}/CN=carme/emailAddress=slurmctld@${CARME_SSL_EMAIL_BASE}" -passin pass:""

  openssl x509 -req -days "${CERT_DAYS}" -in "/tmp/slurmctld.csr" -CA "${BACKEND_CERT}" -CAkey "${BACKEND_KEY}" -set_serial 01 -out "/tmp/slurmctld.crt"

  rm "/tmp/slurmctld.csr" || die "cannot remove '/tmp/slurmctld.csr'"

  chown slurm:slurm "/tmp/slurmctld.key"
  chown slurm:slurm "/tmp/slurmctld.crt"

  chmod 600 "/tmp/slurmctld.key"
  chmod 600 "/tmp/slurmctld.crt"

  mv "/tmp/slurmctld.key" "${SLURMCTLD_KEY}" || die "cannot move '/tmp/slurmctld.key' to '${SLURMCTLD_KEY}'"
  mv "/tmp/slurmctld.crt" "${SLURMCTLD_CERT}" || die "cannot move '/tmp/slurmctld.crt' to '${SLURMCTLD_CERT}'"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# main -----------------------------------------------------------------------------------------------------------------------------

# check if www-data user and group exist
check_for_wwwdata


# create backend certs
create_backend_certs


# create frontend certs
create_frontend_certs


# create slurmctld certs
create_slurmctld_certs

#-----------------------------------------------------------------------------------------------------------------------------------

exit 0
