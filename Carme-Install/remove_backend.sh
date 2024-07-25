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
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})
  CARME_NODE_SSD_PATH=$(get_variable CARME_NODE_SSD_PATH ${FILE_START_CONFIG})
  CARME_NODE_TMP_PATH=$(get_variable CARME_NODE_TMP_PATH ${FILE_START_CONFIG})

  [[ -z ${CARME_HOME} ]] && die "[remove_backend.sh]: CARME_HOME not set."
  [[ -z ${CARME_SYSTEM} ]] && die "[remove_backend.sh]: CARME_SYSTEM not set."
  [[ -z ${CARME_NODE_LIST} ]] && die "[remove_backend.sh]: CARME_NODE_LIST not set."

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
rm -f "${FILE_NODE_CONFIG}"
rm -f "${FILE_NODE_CONFIG}.bak"

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

# remove tmp/scratch directories ----------------------------------------------------------
if [[ ! -z ${CARME_NODE_TMP_PATH}  ]];then
  
  REPLY=""
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    CHECK_TMP_MESSAGE=$"
Do you want to remove \`${CARME_NODE_TMP_PATH}\` directory?
Type \`No\` if you prefer to keep it or do it manually [y/N]: "
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    CHECK_TMP_MESSAGE=$"
Do you want to remove \`${CARME_NODE_TMP_PATH}\` directories in the head-node and the compute-nodes?
Type \`No\` if you prefer to keep them or remove them manually [y/N]: "
  fi

  while ! [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" || $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no" ]]; do
    read -rp "${CHECK_TMP_MESSAGE} " REPLY
    if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
      if ! rm -rf ${CARME_NODE_TMP_PATH}; then
	if [[ ${CARME_SYSTEM} == "single" ]]; then
          die "[remove_backend.sh]: \`${CARME_NODE_TMP_PATH}\` directory was not removed."
	elif [[ ${CARME_SYSTEM} == "multi" ]]; then
          die "[remove_backend.sh]: \`${CARME_NODE_TMP_PATH}\` directory in the head-node was not removed."
	fi
      fi
      for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
        if [[ ${COMPUTE_NODE} != "localhost" ]]; then
          ssh ${COMPUTE_NODE} "if ! rm -rf ${CARME_NODE_TMP_PATH}; then
          echo ''$(date +"[%F %T.%3N]")' ERROR [remove_backend.sh]: \`${CARME_NODE_TMP_PATH}\` directory in compute-node '${COMPUTE_NODE}' was not removed.'; fi; exit 200"
        fi
      done
    elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
      true
    else
      CHECK_TMP_MESSAGE=$'You did not choose yes or no. Please try again [y/N]:'
    fi
  done

fi

if [[ ! -z ${CARME_NODE_SSD_PATH}  ]];then

  REPLY=""
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    CHECK_SSD_MESSAGE=$"
Do you want to remove \`${CARME_NODE_SSD_PATH}\` directory?
Type \`No\` if you prefer to keep it or do it manually [y/N]: "
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    CHECK_SSD_MESSAGE=$"
Do you want to remove \`${CARME_NODE_SSD_PATH}\` directories in the head-node and the compute-nodes?
Type \`No\` if you prefer to keep them or remove them manually [y/N]: "
  fi

  while ! [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" || $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no" ]]; do
    read -rp "${CHECK_SSD_MESSAGE} " REPLY
    if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
      if ! rm -rf ${CARME_NODE_SSD_PATH}; then
   	if [[ ${CARME_SYSTEM} == "single" ]]; then
          die "[remove_backend.sh]: \`${CARME_NODE_SSD_PATH}\` directory was not removed."
	elif [[ ${CARME_SYSTEM} == "multi" ]]; then
          die "[remove_backend.sh]: \`${CARME_NODE_SSD_PATH}\` directory in the head-node was not removed."
	fi
      fi
      for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
        if [[ ${COMPUTE_NODE} != "localhost" ]]; then
          ssh ${COMPUTE_NODE} "if ! rm -rf ${CARME_NODE_SSD_PATH}; then 
	  echo ''$(date +"[%F %T.%3N]")' ERROR [remove_backend.sh]: \`${CARME_NODE_SSD_PATH}\` directory in compute-node '${COMPUTE_NODE}' was not removed.'; fi; exit 200"
        fi
      done
    elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
      true
    else
      CHECK_SSD_MESSAGE=$'You did not choose yes or no. Please try again [y/N]:'
    fi
  done

fi

echo ""
log "carme-backend successfully removed."
