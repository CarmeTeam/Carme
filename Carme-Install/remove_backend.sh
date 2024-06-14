#!/bin/bash
#-----------------------------------------------------------------------------------------#
#----------------------------------- remove BACKEND --------------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then

  CARME_HOME=$(get_variable CARME_USER ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})
  CARME_NODE_SSD_PATH=$(get_variable CARME_NODE_SSD_PATH ${FILE_START_CONFIG})
  CARME_NODE_TMP_PATH=$(get_variable CARME_NODE_TMP_PATH ${FILE_START_CONFIG})

  [[ -z ${CARME_HOME} ]] && die "[remove_backend.sh]: CARME_HOME not set."
  [[ -z ${CARME_NODE_LIST} ]] && die "[remove_backend.sh]: CARME_NODE_LIST not set."
  if [[ ! -z ${CARME_NODE_SSD_PATH}  ]];then
    [[ -d ${CARME_NODE_SSD_PATH} ]] && rm -rf ${CARME_NODE_SSD_PATH}
    [[ -d ${CARME_NODE_SSD_PATH} ]] && die "[remove_backend.sh]: ${CARME_NODE_SSD_PATH} directory was not removed."
  fi
  if [[ ! -z ${CARME_NODE_TMP_PATH}  ]];then
    if [[ ! ${CARME_NODE_TMP_PATH} == "/tmp" ]]; then
      [[ -d ${CARME_NODE_TMP_PATH} ]] && rm -rf ${CARME_NODE_TMP_PATH}
      [[ -d ${CARME_NODE_TMP_PATH} ]] && die "[remove_backend.sh]: ${CARME_NODE_TMP_PATH} directory was not removed."
    fi
  fi

else
  die "[remove_backend.sh]: ${FILE_START_CONFIG} not found."
fi


# uninstall variables ---------------------------------------------------------------------
PATH_MAMBAFORGE=${PATH_CARME}/Carme-Vendors/mambaforge
PATH_SYSTEMD=/etc/systemd/system
PATH_CONFIG=/etc/carme

FILE_BACKEND_SYSTEMD_MULTI=${PATH_SYSTEMD}/multi-user.target.wants/carme-backend.service
FILE_BACKEND_SYSTEMD=${PATH_SYSTEMD}/carme-backend.service
FILE_BACKEND_CONFIG=${PATH_CONFIG}/CarmeConfig.backend
FILE_NODE_CONFIG=${PATH_CONFIG}/CarmeConfig.node

# remove the service ----------------------------------------------------------------------
log "removing backend service..."

if [[ -f ${FILE_BACKEND_SYSTEMD} ]]; then
  systemctl stop carme-backend.service
  rm ${FILE_BACKEND_SYSTEMD}
fi

[[ -h ${FILE_BACKEND_SYSTEMD_MULTI} ]] && rm -f ${FILE_BACKEND_SYSTEMD_MULTI}

systemctl daemon-reload

# remove environments ---------------------------------------------------------------------
log "removing mamba environments..." 

if [[ -f "${PATH_MAMBAFORGE}/etc/profile.d/mamba.sh" ]]; then
  source ${PATH_MAMBAFORGE}/etc/profile.d/mamba.sh
  source ${PATH_MAMBAFORGE}/etc/profile.d/conda.sh
  mamba remove --name carme-backend --all
  mamba remove --name carme-backend-build --all
fi

# remove config files ---------------------------------------------------------------------
log "removing config files..."

rm -f "${FILE_BACKEND_CONFIG}"
rm -f "${FILE_BACKEND_CONFIG}.bak"

for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
  if [[ ${COMPUTE_NODE} == "localhost" ]]; then
    rm -f "${FILE_NODE_CONFIG}"
    rm -f "${FILE_NODE_CONFIG}.bak"
  else
    ssh ${COMPUTE_NODE} "rm -rf ${PATH_CONFIG}"
  fi
done

# remove user/admin directories -----------------------------------------------------------
log "removing  user/admin directories..."

rm -rf "${CARME_HOME}/.config/carme"
rm -rf "${CARME_HOME}/.local/share/carme"

log "carme-backend successfully removed."
