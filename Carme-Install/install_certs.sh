#!/bin/bash
#-----------------------------------------------------------------------------------------#
#-------------------------------- CERTIFICATE installation -------------------------------#
#-----------------------------------------------------------------------------------------#


# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail
#------------------------------------------------------------------------------------------

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# unset proxy -----------------------------------------------------------------------------
if [[ $http_proxy != "" || $https_proxy != "" ]]; then
    http_proxy=""
    https_proxy=""
fi

# config variables --------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then
  
  CARME_USER=$(get_variable CARME_USER ${FILE_START_CONFIG})
  CARME_HOME=$(get_variable CARME_HOME ${FILE_START_CONFIG})
  CARME_GROUP=$(get_variable CARME_GROUP ${FILE_START_CONFIG})

  [[ -z ${CARME_USER} ]] && die "[install_certs.sh]: CARME_USER not set."
  [[ -z ${CARME_HOME} ]] && die "[install_certs.sh]: CARME_HOME not set."
  [[ -z ${CARME_GROUP} ]] && die "[install_certs.sh]: CARME_GROUP not set."

else
  die "[install_certs.sh]: ${FILE_START_CONFIG} not found."
fi

# install variables -----------------------------------------------------------------------

SSL_C="DE"
SSL_L="KL"
SSL_S="RLP"
SSL_O="ITWM"
SSL_OU="CLUSTER"
SSL_EMAIL="@carme"
SSL_CN_BACKEND="carme"
SSL_CN_PROXY="localhost"
SSL_CN_SCRIPTS="slurmctld"
SSL_CN_FRONTEND="frontend"
SSL_ATTRIBUTES="/C=${SSL_C}/ST=${SSL_S}/L=${SSL_L}/O=${SSL_O}/OU=${SSL_OU}"

PATH_CONFIG="${CARME_HOME}/.config"
PATH_USER_SSL="${PATH_CONFIG}/carme/SSL"
PATH_PROXY_SSL="${PATH_CARME}/Carme-Proxy/SSL"
PATH_BACKEND_SSL="${PATH_CARME}/Carme-Backend/SSL"
PATH_SCRIPTS_SSL="${PATH_CARME}/Carme-Scripts/SSL"
PATH_FRONTEND_SSL="${PATH_CARME}/Carme-Frontend/Carme-Django/webfrontend/SSL"

FILE_USER_KEY="${PATH_USER_SSL}/${CARME_USER}.key"
FILE_PROXY_KEY="${PATH_PROXY_SSL}/proxy.key"
FILE_BACKEND_KEY="${PATH_BACKEND_SSL}/backend.key"
FILE_FRONTEND_KEY="${PATH_FRONTEND_SSL}/frontend.key"
FILE_SLURMCTLD_KEY="${PATH_SCRIPTS_SSL}/slurmctld.key"

FILE_USER_CRT="${PATH_USER_SSL}/${CARME_USER}.crt"
FILE_PROXY_CRT="${PATH_PROXY_SSL}/proxy.crt"
FILE_BACKEND_CRT="${PATH_BACKEND_SSL}/backend.crt"
FILE_FRONTEND_CRT="${PATH_FRONTEND_SSL}/frontend.crt"
FILE_SLURMCTLD_CRT="${PATH_SCRIPTS_SSL}/slurmctld.crt"

FILE_USER_CSR="${PATH_USER_SSL}/${CARME_USER}.csr"
FILE_FRONTEND_CSR="${PATH_FRONTEND_SSL}/frontend.csr"
FILE_SLURMCTLD_CSR="${PATH_SCRIPTS_SSL}/slurmctld.csr"

BITS_RATE="4096"
CERT_DAYS="3650"

# installation starts ----------------------------------------------------------------------
log "starting certs creation..."

# verify www-data --------------------------------------------------------------------------

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

if ! [[ "${WWW_DATA_USER}" == "true" && "${WWW_DATA_GROUP}" == "true" ]];then
  if [[ "${WWW_DATA_USER}" == "false" && "${WWW_DATA_GROUP}" == "false" ]]; then
    die "[install_certs.sh]: www-data user and group do not exist in your system."
  elif [[ "${WWW_DATA_USER}" == "false" ]]; then
    die "[install_certs.sh]: www-data user does not exist in your system. Please contact us."
  elif [[ "${WWW_DATA_GROUP}" == "false" ]]; then
    die "[install_certs.sh]: www-data group does not exist in your system. Please contact us."
  fi
fi


# backend certs ----------------------------------------------------------------------------
log "creating backend certs..."

mkdir -p "${PATH_BACKEND_SSL}" || die "[install_certs.sh]: cannot create '${PATH_BACKEND_SSL}'."

openssl genrsa -out "${FILE_BACKEND_KEY}" "${BITS_RATE}"
openssl req -new -x509 -days "${CERT_DAYS}" -key "${FILE_BACKEND_KEY}" -out "${FILE_BACKEND_CRT}" -subj "${SSL_ATTRIBUTES}/CN=${SSL_CN_BACKEND}/emailAddress=${SSL_CN_BACKEND}${SSL_EMAIL}"

[[ -f "${FILE_BACKEND_KEY}" ]] || die "[install_certs.sh]: cannot create '${FILE_BACKEND_KEY}'."
[[ -f "${FILE_BACKEND_CRT}" ]] || die "[install_certs.sh]: cannot create '${FILE_BACKEND_CRT}'."

chmod 600 "${FILE_BACKEND_KEY}"
chmod 600 "${FILE_BACKEND_CRT}"

# frontend certs ------------------------------------------------------------------------------
log "creating frontend certs..."

mkdir -p "${PATH_FRONTEND_SSL}" || die "[install_certs.sh]: cannot create '${PATH_FRONTEND_SSL}'."

openssl genrsa -out "${FILE_FRONTEND_KEY}" "${BITS_RATE}"
openssl req -new -key "${FILE_FRONTEND_KEY}" -out "${FILE_FRONTEND_CSR}" -subj "${SSL_ATTRIBUTES}/CN=${SSL_CN_FRONTEND}/emailAddress=${SSL_CN_FRONTEND}${SSL_EMAIL}" -passin pass:""
openssl x509 -req -days "${CERT_DAYS}" -in "${FILE_FRONTEND_CSR}" -CA "${FILE_BACKEND_CRT}" -CAkey "${FILE_BACKEND_KEY}" -set_serial 01 -out "${FILE_FRONTEND_CRT}"

[[ -f "${FILE_FRONTEND_KEY}" ]] || die "[install_certs.sh]: cannot create '${FILE_FRONTEND_KEY}'."
[[ -f "${FILE_FRONTEND_CRT}" ]] || die "[install_certs.sh]: cannot create '${FILE_FRONTEND_CRT}'."
[[ -f "${FILE_FRONTEND_CSR}" ]] && rm "${FILE_FRONTEND_CSR}"

chown www-data:www-data "${FILE_FRONTEND_KEY}"
chown www-data:www-data "${FILE_FRONTEND_CRT}"
chmod 600 "${FILE_FRONTEND_KEY}"
chmod 600 "${FILE_FRONTEND_CRT}"

# scripts certs --------------------------------------------------------------------------------
log "creating scripts certs..."

mkdir -p "${PATH_SCRIPTS_SSL}" || die "[install_certs.sh]: cannot create '${PATH_SCRIPTS_SSL}'."

openssl genrsa -out "${FILE_SLURMCTLD_KEY}" "${BITS_RATE}"
openssl req -new -key "${FILE_SLURMCTLD_KEY}" -out "${FILE_SLURMCTLD_CSR}" -subj "${SSL_ATTRIBUTES}/CN=${SSL_CN_SCRIPTS}/emailAddress=${SSL_CN_SCRIPTS}${SSL_EMAIL}" -passin pass:""
openssl x509 -req -days "${CERT_DAYS}" -in "${FILE_SLURMCTLD_CSR}" -CA "${FILE_BACKEND_CRT}" -CAkey "${FILE_BACKEND_KEY}" -set_serial 01 -out "${FILE_SLURMCTLD_CRT}"

[[ -f "${FILE_SLURMCTLD_KEY}" ]] || die "[install_certs.sh]: cannot create '${FILE_SLURMCTLD_KEY}'."
[[ -f "${FILE_SLURMCTLD_CRT}" ]] || die "[install_certs.sh]: cannot create '${FILE_SLURMCTLD_CRT}'."
[[ -f "${FILE_SLURMCTLD_CSR}" ]] && rm "${FILE_SLURMCTLD_CSR}"

chown slurm:slurm "${FILE_SLURMCTLD_KEY}"
chown slurm:slurm "${FILE_SLURMCTLD_CRT}"
chmod 600 "${FILE_SLURMCTLD_KEY}"
chmod 600 "${FILE_SLURMCTLD_CRT}"

# user certs ------------------------------------------------------------------------------------
log "creating user certs..."

mkdir -p "${PATH_USER_SSL}" || die "[install_certs.sh]: cannot create '${PATH_USER_SSL}'."

openssl genrsa -out "${FILE_USER_KEY}" "${BITS_RATE}"
openssl req -new -key "${FILE_USER_KEY}" -out "${FILE_USER_CSR}" -subj "${SSL_ATTRIBUTES}/CN=${CARME_USER}/emailAddress=${CARME_USER}${SSL_EMAIL}" -passin pass:""
openssl x509 -req -days "${CERT_DAYS}" -in "${FILE_USER_CSR}" -CA "${FILE_BACKEND_CRT}" -CAkey "${FILE_BACKEND_KEY}" -set_serial 01 -out "${FILE_USER_CRT}"

[[ -f "${FILE_USER_KEY}" ]] || die "[install_certs.sh]: cannot create '${FILE_USER_KEY}'."
[[ -f "${FILE_USER_CRT}" ]] || die "[install_certs.sh]: cannot create '${FILE_USER_CRT}'."
[[ -f "${FILE_USER_CSR}" ]] && rm "${FILE_USER_CSR}"

chown -R "${CARME_USER}":"${CARME_GROUP}" "${PATH_CONFIG}"
chmod 600 "${FILE_USER_KEY}"
chmod 600 "${FILE_USER_CRT}"

# proxy certs ------------------------------------------------------------------------------------
log "creating proxy certs..."

mkdir -p "${PATH_PROXY_SSL}" || die "[install_certs.sh]: cannot create '${PATH_PROXY_SSL}'."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "${FILE_PROXY_KEY}" -out "${FILE_PROXY_CRT}" -subj "${SSL_ATTRIBUTES}/CN=${SSL_CN_PROXY}/emailAddress=${SSL_CN_PROXY}${SSL_EMAIL}"

chown www-data:www-data "${FILE_PROXY_KEY}"
chown www-data:www-data "${FILE_PROXY_CRT}"
chmod 600 "${FILE_PROXY_KEY}"
chmod 600 "${FILE_PROXY_CRT}"

log "SSL certificates successfully created."
