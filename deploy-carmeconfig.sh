#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# deployCarmeConfig.sh deploys the CarmeConfig into separate files
#
# COPYRIGHT: Fraunhofer ITWM, 2021
# LICENCE: http://open-carme.org/LICENSE.md 
# CONTACT: info@open-carme.org
#----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define path to carme installation ------------------------------------------------------------------------------------------------
CARME_DIR="/opt/Carme"
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
PATH_TO_SCRIPTS_FOLDER="${CARME_DIR}/Carme-Scripts"
if [[ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ]];then
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


# define function to extract parameters from another file --------------------------------------------------------------------------
VARIABLES_PARAMETER_FILE="${CARME_DIR}/variables.conf"
if [[ -f ${VARIABLES_PARAMETER_FILE} ]];then
  function get_parameter () {
    PARAMETER=$(grep --color=never -Po "^${1}=\K.*" "${VARIABLES_PARAMETER_FILE}")
    PARAMETER=$(echo "${PARAMETER}" | tr -d '"')
    echo "${PARAMETER}"
  }
else
  die "${VARIABLES_PARAMETER_FILE} not found"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# source the variables that have to be imported from /opt/Carme/CarmeConfig --------------------------------------------------------
FRONTEND_VARIABLES=$(get_parameter FRONTEND_VARIABLES)
CONTAINER_VARIABLES=$(get_parameter CONTAINER_VARIABLES)
BACKEND_VARIABLES=$(get_parameter BACKEND_VARIABLES)
#-----------------------------------------------------------------------------------------------------------------------------------


# source needed variables /opt/Carme/CarmeConfig -----------------------------------------------------------------------------------
CARME_FRONTEND_PATH=$(get_variable CARME_FRONTEND_PATH)
CARME_SCRIPTS_PATH=$(get_variable CARME_SCRIPTS_PATH)
CARME_HEADNODE_NAME=$(get_variable CARME_HEADNODE_NAME)
CARME_LOGINNODE_NAME=$(get_variable CARME_LOGINNODE_NAME)
CARME_NODES_LIST=$(get_variable CARME_NODES_LIST)

[[ -z ${CARME_FRONTEND_PATH} ]] && die "CARME_FRONTEND_PATH not set"
[[ -z ${CARME_SCRIPTS_PATH} ]] && die "CARME_SCRIPTS_PATH not set"
[[ -z ${CARME_HEADNODE_NAME} ]] && die "CARME_HEADNODE_NAME not set"
[[ -z ${CARME_LOGINNODE_NAME} ]] && die "CARME_LOGINNODE_NAME not set"
[[ -z ${CARME_NODES_LIST} ]] && die "CARME_NODES_LIST not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if node is headnode --------------------------------------------------------------------------------------------------------
if [[ "$(hostname -s)" -ne "${CARME_HEADNODE_NAME}" ]];then
  die "your are not on the headnode"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if things should be done locally -------------------------------------------------------------------------------------------
if [[ "${1}" == "local" ]];then
  LOCAL="true"
  echo "NOTE: the different carme config files are only deployed on this node ($(hostname -s))"
  echo ""
else
  LOCAL="false"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# variables ------------------------------------------------------------------------------------------------------------------------
# config file
CONFIG_FILE="${CARME_DIR}/CarmeConfig"


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


# define frontend config and backup file
FRONTEND_CONFIG="${CARME_FRONTEND_PATH}/CarmeConfig.frontend"
FRONTEND_CONFIG_OLD="${CARME_FRONTEND_PATH}/CarmeConfig.frontend.bak"


# define container config and backup file
CONTAINER_CONFIG="${CARME_SCRIPTS_PATH}/InsideContainer/CarmeConfig.node"
CONTAINER_CONFIG_OLD="${CARME_SCRIPTS_PATH}/InsideContainer/CarmeConfig.node.bak"


# define backend config and backup file
BACKEND_CONFIG="Carme-Backend/CarmeConfig.backend"
BACKEND_CONFIG_OLD="Carme-Backend/CarmeConfig.backend.bak"
#-----------------------------------------------------------------------------------------------------------------------------------


# subroutine: collect variables needed in the frontend -----------------------------------------------------------------------------
echo "CarmeConfig.frontend: collect variables needed in the webfrontend"


echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Frontend Config
#
# WARNING: This file is generated automatically by deploy-carmeconfig.sh.
#          Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > "CarmeConfig.frontend.new"


for VARIABLE in ${FRONTEND_VARIABLES};do
  grep "^${VARIABLE}=" "${CONFIG_FILE}" >> CarmeConfig.frontend.new
done


if [[ "${WWW_DATA_USER}" == "true" && "${WWW_DATA_GROUP}" == "true" ]];then

  # change ownership of CarmeConfig.frontend
  chown www-data:www-data "CarmeConfig.frontend.new"

  # change permissions of new CarmeConfig.frontend
  chmod 600 "CarmeConfig.frontend.new" || die "cannot change file permissions of CarmeConfig.frontend.new"

else

  if [[ "${WWW_DATA_USER}" == "false" && "${WWW_DATA_GROUP}" == "false" ]];then
    echo "WARNING: www-data user and group do not exist"
    echo "         set frontend config permissions as '644' and user 'root'"
  elif [[ "${WWW_DATA_USER}" == "false" ]];then
    echo "WARNING: www-data user does not exist"
    echo "         set frontend config permissions as '644' and user 'root'"
  elif [[ "${WWW_DATA_GROUP}" == "false" ]];then
    echo "WARNING: www-data group does not exist"
    echo "         set frontend config permissions as '644' and user 'root'"
  fi

  # change permissions of new CarmeConfig.frontend
  chmod 644 "CarmeConfig.frontend.new" || die "cannot change file permissions of CarmeConfig.frontend.new"

fi


# move carme config frontend to right folder
if [[ "${CARME_HEADNODE_NAME}" == "${CARME_LOGINNODE_NAME}" || "${LOCAL}" == "true" ]];then
  [[ -f ${FRONTEND_CONFIG} ]] && mv "${FRONTEND_CONFIG}" "${FRONTEND_CONFIG_OLD}"
  mv "CarmeConfig.frontend.new" "${FRONTEND_CONFIG}" || die "cannot move CarmeConfig.frontend.new to ${FRONTEND_CONFIG}"
else
  ssh "${CARME_LOGINNODE_NAME}" -t "[[ -f ${FRONTEND_CONFIG} ]] && mv ${FRONTEND_CONFIG} ${FRONTEND_CONFIG_OLD}"
  scp -p "CarmeConfig.frontend.new" "${CARME_LOGINNODE_NAME}:${FRONTEND_CONFIG}" || die "cannot copy CarmeConfig.frontend.new to ${CARME_LOGINNODE_NAME}"
  rm "CarmeConfig.frontend.new" || die "cannot remove CarmeConfig.frontend.new"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# subroutine: collect variables needed inside the containers -----------------------------------------------------------------------
echo "CarmeConfig.node: collect variables needed in the job"


echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Container Config
# 
# WARNING: This file is generated automatically by deploy-carmeconfig.sh.
#          Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > CarmeConfig.node.new


for VARIABLE in ${CONTAINER_VARIABLES};do
  grep "^${VARIABLE}=" "${CONFIG_FILE}" >> CarmeConfig.node.new
done


# change permissions of new CarmeConfig.node
chmod 644 CarmeConfig.node.new || die "cannot change file permissions of CarmeConfig.node.new"


# move carme config frontend to right folder
[[ -d "${CARME_SCRIPTS_PATH}/InsideContainer" ]] &&  cp "CarmeConfig.node.new" "${CONTAINER_CONFIG}"


if [[ "${LOCAL}" == "false" ]];then
  for COMPUTE_NODE in ${CARME_NODES_LIST}; do
    echo -e "${COMPUTE_NODE}:\tcopy computenode files to ${COMPUTE_NODE}:${CARME_INSTALL_DIR}"
    ssh "${COMPUTE_NODE}" -t "[[ -f ${CONTAINER_CONFIG} ]] && mv ${CONTAINER_CONFIG} ${CONTAINER_CONFIG_OLD}"
    scp -p "CarmeConfig.node.new" "${COMPUTE_NODE}:${CONTAINER_CONFIG}"
    echo ""
  done
fi

rm "CarmeConfig.node.new" || die "cannot remove CarmeConfig.node.new"
#-----------------------------------------------------------------------------------------------------------------------------------


# subroutine: collect variables needed in the backend ------------------------------------------------------------------------------
echo "CarmeConfig.backend: collect variables needed in the backend"


echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Backend Config
#
# WARNING: This file is generated automatically by deploy-carmeconfig.sh.
#          Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > "CarmeConfig.backend.new"


for VARIABLE in ${BACKEND_VARIABLES};do
  grep "^${VARIABLE}=" "${CONFIG_FILE}" >> "CarmeConfig.backend.new"
done


# change permissions of new CarmeConfig.backend
chmod 644 "CarmeConfig.backend.new" || die "cannot change file permissions of CarmeConfig.backend.new"


# move carme config backend to right folder
[[ -f "${BACKEND_CONFIG}" ]] && mv "${BACKEND_CONFIG}" "${BACKEND_CONFIG_OLD}"
mv "CarmeConfig.backend.new" "${BACKEND_CONFIG}"
#-----------------------------------------------------------------------------------------------------------------------------------
