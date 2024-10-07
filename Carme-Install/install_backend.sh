#!/bin/bash
#-----------------------------------------------------------------------------------------#
#-------------------------------- BACKEND installation -----------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# unset proxy -----------------------------------------------------------------------------
if [[ $http_proxy != "" || $https_proxy != "" ]]; then
    http_proxy=""
    https_proxy=""
fi

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then

  SYSTEM_ARCH=$(get_variable SYSTEM_ARCH ${FILE_START_CONFIG})
  SYSTEM_DIST=$(get_variable SYSTEM_DIST ${FILE_START_CONFIG})

  CARME_UID=$(get_variable CARME_UID ${FILE_START_CONFIG})
  CARME_USER=$(get_variable CARME_USER ${FILE_START_CONFIG})
  CARME_HOME=$(get_variable CARME_HOME ${FILE_START_CONFIG})
  CARME_GROUP=$(get_variable CARME_GROUP ${FILE_START_CONFIG})
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})

  CARME_DB_DEFAULT_NAME=$(get_variable CARME_DB_DEFAULT_NAME ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_PASS=$(get_variable CARME_PASSWORD_DJANGO ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_NODE=$(get_variable CARME_DB_DEFAULT_NODE ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_USER=$(get_variable CARME_DB_DEFAULT_USER ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_PORT=$(get_variable CARME_DB_DEFAULT_PORT ${FILE_START_CONFIG})
  
  CARME_LDAP_SERVER_PROTO=$(get_variable CARME_LDAP_SERVER_PROTO ${FILE_START_CONFIG})
  CARME_LDAP_SERVER_IP=$(get_variable CARME_LDAP_SERVER_IP ${FILE_START_CONFIG})
  CARME_LDAP_BASE_DN=$(get_variable CARME_LDAP_BASE_DN ${FILE_START_CONFIG})
  CARME_LDAP_BIND_DN=$(get_variable CARME_LDAP_BIND_DN ${FILE_START_CONFIG})
  CARME_LDAP_SERVER_PW=$(get_variable CARME_LDAP_SERVER_PW ${FILE_START_CONFIG})

  CARME_FRONTEND_IP=$(get_variable CARME_FRONTEND_IP ${FILE_START_CONFIG})
  CARME_FRONTEND_ID=$(get_variable CARME_FRONTEND_ID ${FILE_START_CONFIG})
  CARME_FRONTEND_URL=$(get_variable CARME_FRONTEND_URL ${FILE_START_CONFIG})
  CARME_FRONTEND_NODE=$(get_variable CARME_FRONTEND_NODE ${FILE_START_CONFIG})
  
  CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${FILE_START_CONFIG})
  CARME_BACKEND_NODE=$(get_variable CARME_BACKEND_NODE ${FILE_START_CONFIG})

  CARME_NODE_FS=$(get_variable CARME_NODE_FS ${FILE_START_CONFIG})
  CARME_NODE_SSHD=$(get_variable CARME_NODE_SSHD ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})
  CARME_NODE_SSD_PATH=$(get_variable CARME_NODE_SSD_PATH ${FILE_START_CONFIG})
  CARME_NODE_TMP_PATH=$(get_variable CARME_NODE_TMP_PATH ${FILE_START_CONFIG})

  [[ -z ${SYSTEM_ARCH} ]] && die "[install_backend.sh]: SYSTEM_ARCH not set."
  [[ -z ${SYSTEM_DIST} ]] && die "[install_backend.sh]: SYSTEM_DIST not set."

  [[ -z ${CARME_UID} ]] && die "[install_backend.sh]: CARME_UID not set."
  [[ -z ${CARME_USER} ]] && die "[install_backend.sh]: CARME_USER not set."
  [[ -z ${CARME_HOME} ]] && die "[install_backend.sh]: CARME_HOME not set."
  [[ -z ${CARME_GROUP} ]] && die "[install_backend.sh]: CARME_GROUP not set."

  [[ -z ${CARME_DB_DEFAULT_NAME} ]] && die "[install_backend.sh]: CARME_DB_DEFAULT_NAME not set."
  [[ -z ${CARME_DB_DEFAULT_NODE} ]] && die "[install_backend.sh]: CARME_DB_DEFAULT_NODE not set."
  [[ -z ${CARME_DB_DEFAULT_PASS} ]] && die "[install_backend.sh]: CARME_DB_DEFAULT_PASS not set."
  [[ -z ${CARME_DB_DEFAULT_USER} ]] && die "[install_backend.sh]: CARME_DB_DEFAULT_USER not set."
  [[ -z ${CARME_DB_DEFAULT_PORT} ]] && die "[install_backend.sh]: CARME_DB_DEFAULT_PORT not set."

  [[ -z ${CARME_FRONTEND_IP} ]] && die "[install_backend.sh]: CARME_FRONTEND_IP not set."
  [[ -z ${CARME_FRONTEND_ID} ]] && die "[install_backend.sh]: CARME_FRONTEND_ID not set."
  [[ -z ${CARME_FRONTEND_URL} ]] && die "[install_backend.sh]: CARME_FRONTEND_URL not set."
  [[ -z ${CARME_FRONTEND_NODE} ]] && die "[install_backend.sh]: CARME_FRONTEND_NODE not set."

  [[ -z ${CARME_BACKEND_PORT} ]] && die "[install_backend.sh]: CARME_BACKEND_PORT not set."
  [[ -z ${CARME_BACKEND_NODE} ]] && die "[install_backend.sh]: CARME_BACKEND_NODE not set."

  [[ -z ${CARME_NODE_FS} ]] && die "[install_backend.sh]: CARME_NODE_FS not set."
  [[ -z ${CARME_NODE_SSHD} ]] && die "[install_backend.sh]: CARME_NODE_SSHD not set."
  [[ -z ${CARME_NODE_LIST} ]] && die "[install_backend.sh]: CARME_NODE_LIST not set."
  if [[ ! -z ${CARME_NODE_SSD_PATH}  ]];then
    [[ ! -d ${CARME_NODE_SSD_PATH} ]] && mkdir ${CARME_NODE_SSD_PATH}
    [[ ! -d ${CARME_NODE_SSD_PATH} ]] && die "[install_backend.sh]: ${CARME_NODE_SSD_PATH} directory was not created."
  fi
  if [[ ! -z ${CARME_NODE_TMP_PATH}  ]];then
    [[ ! -d ${CARME_NODE_TMP_PATH} ]] && mkdir ${CARME_NODE_TMP_PATH}
    [[ ! -d ${CARME_NODE_TMP_PATH} ]] && die "[install_backend.sh]: ${CARME_NODE_TMP_PATH} directory was not created."
  fi

  [[ -z ${CARME_LDAP_SERVER_PROTO} ]] && die "[install_frontend.sh]: CARME_LDAP_SERVER_PROTO not set."
  [[ -z ${CARME_LDAP_SERVER_IP} ]] && die "[install_frontend.sh]: CARME_LDAP_SERVER_IP not set."
  [[ -z ${CARME_LDAP_BASE_DN} ]] && die "[install_frontend.sh]: CARME_LDAP_BASE_DN not set."
  [[ -z ${CARME_LDAP_BIND_DN} ]] && die "[install_frontend.sh]: CARME_LDAP_BIND_DN not set."
  [[ -z ${CARME_LDAP_SERVER_PW} ]] && die "[install_frontend.sh]: CARME_LDAP_SERVER_PW not set."

else
  die "[install_backend.sh]: ${FILE_START_CONFIG} not found."
fi

# install variables ----------------------------------------------------------------------

PATH_MAMBAFORGE=${PATH_CARME}/Carme-Vendors/mambaforge
PATH_BACKEND=${PATH_CARME}/Carme-Backend
PATH_SCRIPTS=${PATH_CARME}/Carme-Scripts
PATH_SYSTEMD=/etc/systemd/system
PATH_CONFIG=/etc/carme
PATH_PROXY=/opt/Carme-Proxy-Routes

FILE_BACKEND_SYSTEMD=${PATH_SYSTEMD}/carme-backend.service
FILE_BACKEND_CONFIG=${PATH_CONFIG}/CarmeConfig.backend
FILE_BACKEND_BIN=${PATH_MAMBAFORGE}/envs/carme-backend/bin/carme-backend
FILE_NODE_CONFIG=${PATH_CONFIG}/CarmeConfig.node

# installation starts ---------------------------------------------------------------------
log "starting backend installation..."

# create carme user directories -----------------------------------------------------------
log "creating carme user directories..."

mkdir -p "${CARME_HOME}/.config/carme"
chown -R "${CARME_USER}":"${CARME_GROUP}" "${CARME_HOME}/.config"
mkdir -p "${CARME_HOME}/.local/share/carme"
chown -R "${CARME_USER}":"${CARME_GROUP}" "${CARME_HOME}/.local"
mkdir -p "${CARME_HOME}/.ssh"
chown -R "${CARME_USER}":"${CARME_GROUP}" "${CARME_HOME}/.ssh"

# create config ---------------------------------------------------------------------------
log "creating backend config..."

mkdir -p ${PATH_CONFIG} || die "[install_backend.sh]: cannot create path ${PATH_CONFIG}."
[[ -f "${FILE_BACKEND_CONFIG}" ]] && mv "${FILE_BACKEND_CONFIG}" "${FILE_BACKEND_CONFIG}.bak"
touch ${FILE_BACKEND_CONFIG}
cat << EOF >> ${FILE_BACKEND_CONFIG}
#------------------------------------------------------------------------------------------
# CarmeConfig.backend
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_backend.sh
#------------------------------------------------------------------------------------------ 
#
# USER ------------------------------------------------------------------------------------
CARME_UID="${CARME_UID}"
CARME_USER="${CARME_USER}"
CARME_HOME="${CARME_HOME}"
CARME_GROUP="${CARME_GROUP}"
#
# DB --------------------------------------------------------------------------------------
CARME_DB_DEFAULT_PASS="${CARME_DB_DEFAULT_PASS}"
CARME_DB_DEFAULT_NAME="${CARME_DB_DEFAULT_NAME}"
CARME_DB_DEFAULT_NODE="${CARME_DB_DEFAULT_NODE}"
CARME_DB_DEFAULT_USER="${CARME_DB_DEFAULT_USER}"
CARME_DB_DEFAULT_PORT="${CARME_DB_DEFAULT_PORT}"
#
# FRONTEND --------------------------------------------------------------------------------
CARME_FRONTEND_ID="${CARME_FRONTEND_ID}"
CARME_FRONTEND_URL="${CARME_FRONTEND_URL}"
CARME_FRONTEND_NODE="${CARME_FRONTEND_NODE}"
#
# BACKEND ---------------------------------------------------------------------------------
CARME_BACKEND_PORT="${CARME_BACKEND_PORT}"
CARME_BACKEND_SERVER="${CARME_BACKEND_NODE}"
#
# PATHS -----------------------------------------------------------------------------------
CARME_PATH_BACKEND="${PATH_BACKEND}"
CARME_PATH_SCRIPTS="${PATH_SCRIPTS}"
CARME_PATH_PROXY_ROUTES="${PATH_PROXY}"
#
# LDAP ------------------------------------------------------------------------------------
CARME_LDAP_SERVER_PROTO="${CARME_LDAP_SERVER_PROTO}"
CARME_LDAP_SERVER_IP="${CARME_LDAP_SERVER_IP}"
CARME_LDAP_BASE_DN="${CARME_LDAP_BASE_DN}"
CARME_LDAP_BIND_DN="${CARME_LDAP_BIND_DN}"
CARME_LDAP_SERVER_PW="${CARME_LDAP_SERVER_PW}"
EOF


log "creating node config..."

mkdir -p ${PATH_CONFIG} || die "[install_backend.sh]: cannot create path ${PATH_CONFIG}."
[[ -f "${FILE_NODE_CONFIG}" ]] && mv "${FILE_NODE_CONFIG}" "${FILE_NODE_CONFIG}.bak"
touch ${FILE_NODE_CONFIG}
cat << EOF >> ${FILE_NODE_CONFIG}
#------------------------------------------------------------------------------------------
# CarmeConfig.node
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_backend.sh
#------------------------------------------------------------------------------------------
#
# FRONTEND --------------------------------------------------------------------------------
CARME_FRONTEND_IP=${CARME_FRONTEND_IP}
CARME_FRONTEND_URL=${CARME_FRONTEND_URL}
#
# BACKEND ---------------------------------------------------------------------------------
CARME_BACKEND_PORT=${CARME_BACKEND_PORT}
CARME_BACKEND_NODE=${CARME_BACKEND_NODE}
#
# NODES -----------------------------------------------------------------------------------
CARME_NODE_FS=${CARME_NODE_FS}
CARME_NODE_SSHD=${CARME_NODE_SSHD}
CARME_NODE_SSD_PATH=${CARME_NODE_SSD_PATH}
CARME_NODE_TMP_PATH=${CARME_NODE_TMP_PATH}
EOF

# copy config to compute nodes ------------------------------------------------------------
if [[ ${CARME_SYSTEM} == "single" ]]; then
  log "copying node config to localhost..."
elif [[ ${CARME_SYSTEM} == "multi" ]]; then
  log "copying node config to compute nodes..."
fi

for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
  ssh ${COMPUTE_NODE} "mkdir -p ${PATH_CONFIG}"
  scp -q ${FILE_NODE_CONFIG} ${COMPUTE_NODE}:${FILE_NODE_CONFIG} || die "[install_backend.sh]: scp to ${COMPUTE_NODE} did not work."  
done


# set SSD and TMP in compute nodes --------------------------------------------------------
if [[ ${CARME_SYSTEM} == "single" ]]; then
  log "creating node directories in localhost..."
elif [[ ${CARME_SYSTEM} == "multi" ]]; then
  log "creating node directories in compute nodes..."
fi

for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
  ssh ${COMPUTE_NODE} "mkdir -p ${CARME_NODE_SSD_PATH}"
  ssh ${COMPUTE_NODE} "mkdir -p ${CARME_NODE_TMP_PATH}"
done

# create the wheel ------------------------------------------------------------------------
log "building backend wheel..."

[[ -f "${PATH_MAMBAFORGE}/etc/profile.d/conda.sh" ]] || 
die "[install_backend.sh]: ${PATH_MAMBAFORGE}/etc/profile.d/conda.sh was not found."

[[ -f "${PATH_MAMBAFORGE}/etc/profile.d/mamba.sh" ]] || 
die "[install_backend.sh]: ${PATH_MAMBAFORGE}/etc/profile.d/mamba.sh was not found."

source ${PATH_MAMBAFORGE}/etc/profile.d/conda.sh
source ${PATH_MAMBAFORGE}/etc/profile.d/mamba.sh

if [[ -d "${PATH_MAMBAFORGE}/envs/carme-backend-build" ]];then
  mamba activate carme-backend-build
  if [[ -d "${PATH_BACKEND}/Python/dist" ]];then
    rm -r ${PATH_BACKEND}/Python/dist
  fi
else
  mamba create -n carme-backend-build python=3 -y
  mamba activate carme-backend-build
fi

pip install --upgrade setuptools --root-user-action=ignore
pip install --upgrade build --root-user-action=ignore

cd ${PATH_BACKEND}/Python
python3 -m build
mamba deactivate

# install the wheel -----------------------------------------------------------------------
log "installing backend wheel..."

if [[ -d "${PATH_MAMBAFORGE}/envs/carme-backend" ]];then
  mamba activate carme-backend
else
  mamba create -n carme-backend python=3 -y
  mamba activate carme-backend
fi

if [[ ${SYSTEM_ARCH} == "amd64" && ${SYSTEM_DIST} == "ubuntu" ]]; then
  install_packages libmysqlclient-dev
elif [[ ${SYSTEM_DIST} == "rocky" ]]; then
  install_packages mysql-devel
else
  install_packages libmariadb-dev
fi
install_packages gcc

pip install --force-reinstall ${PATH_BACKEND}/Python/dist/carme_backend*.whl --root-user-action=ignore
mamba deactivate

# install the service ---------------------------------------------------------------------
log "creating backend service..."

if [[ -f ${FILE_BACKEND_SYSTEMD} ]]; then
  systemctl stop carme-backend.service
  rm ${FILE_BACKEND_SYSTEMD}
fi
touch ${FILE_BACKEND_SYSTEMD}

[[ -f ${FILE_BACKEND_BIN} ]] || die "[install_backend.sh]: ${FILE_BACKEND_BIN} not found."

cat << EOF >> ${FILE_BACKEND_SYSTEMD}
[Unit]
Description=Carme Backend
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
Environment=PYTHONUNBUFFERED=1
ExecStart=${FILE_BACKEND_BIN} ${FILE_BACKEND_CONFIG}

Restart=on-failure
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start carme-backend.service
systemctl enable carme-backend.service

systemctl is-active --quiet carme-backend.service && 
log "carme-backend successfully installed." || 
die "[install_backend.sh]: carme-backend.service is not running."
