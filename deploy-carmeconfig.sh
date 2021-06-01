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


# define function to extract parameters from another file --------------------------------------------------------------------------
VARIABLES_PARAMETER_FILE="variables.conf"
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


# define carme config file ---------------------------------------------------------------------------------------------------------
CONFIG_FILE="CarmeConfig"
#-----------------------------------------------------------------------------------------------------------------------------------


# collect variables needed in the frontend -----------------------------------------------------------------------------------------
echo "CarmeConfig.frontend: collect variables needed in the webfrontend"


echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Frontend Config
#
# WARNING: This file is generated automatically by deployCarmeConfig.sh. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > "CarmeConfig.frontend.new"


for VARIABLE in ${FRONTEND_VARIABLES};do
  grep "^${VARIABLE}=" "${CONFIG_FILE}" >> CarmeConfig.frontend.new
done


# change permissions of new CarmeConfig.frontend
chmod 600 "CarmeConfig.frontend.new" || die "cannot change file permissions of CarmeConfig.frontend.new"


# change ownership of CarmeConfig.frontend
chown www-data:www-data "CarmeConfig.frontend.new"


# move carme config frontend to right folder
ssh ${CARME_LOGINNODE_NAME} -X -t "mv ${CARME_FRONTEND_PATH}/CarmeConfig.frontend ${CARME_FRONTEND_PATH}/CarmeConfig.frontend.bak"
scp -p "CarmeConfig.frontend.new" "${CARME_LOGINNODE_NAME}:${CARME_FRONTEND_PATH}/CarmeConfig.frontend"


# remove helper config
rm "CarmeConfig.frontend.new"
#-----------------------------------------------------------------------------------------------------------------------------------


# collect variables needed inside the containers -----------------------------------------------------------------------------------
echo "CarmeConfig.container: collect variables needed in the job"


echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Container Config
# 
# WARNING: This file is generated automatically by deployCarmeConfig.sh. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > CarmeConfig.container.new


for VARIABLE in ${CONTAINER_VARIABLES};do
  grep "^${VARIABLE}=" "${CONFIG_FILE}" >> CarmeConfig.container.new
done


# change permissions of new CarmeConfig.container
chmod 644 CarmeConfig.container.new || die "cannot change file permissions of CarmeConfig.container.new"


# move carme config frontend to right folder
mv "CarmeConfig.container.new" "computenode/Carme-Scripts/InsideContainer/CarmeConfig.container"


for COMPUTE_NODE in ${CARME_NODES_LIST}; do
  echo -e "${COMPUTE_NODE}:\tcopy computenode files to ${COMPUTE_NODE}:${CARME_INSTALL_DIR}"
  ssh ${COMPUTE_NODE} -X -t "mv ${CARME_SCRIPTS_PATH}/InsideContainer/CarmeConfig.container ${CARME_SCRIPTS_PATH}/InsideContainer/CarmeConfig.container.bak"
  scp -p "CarmeConfig.container.new" "${COMPUTE_NODE}:${CARME_SCRIPTS_PATH}/InsideContainer/CarmeConfig.container"
  echo ""
done


# remove helper config
rm "CarmeConfig.container.new"
#-----------------------------------------------------------------------------------------------------------------------------------


# collect variables needed in the backend ------------------------------------------------------------------------------------------
echo "CarmeConfig.backend: collect variables needed in the backend"


echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Backend Config
#
# WARNING: This file is generated automatically by deployCarmeConfig.sh. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > "CarmeConfig.backend.new"


for VARIABLE in ${BACKEND_VARIABLES};do
  grep "^${VARIABLE}=" "${CONFIG_FILE}" >> "CarmeConfig.backend.new"
done


# change permissions of new CarmeConfig.backend
chmod 644 "CarmeConfig.backend.new" || die "cannot change file permissions of CarmeConfig.backend.new"


# move carme config backend to right folder
mv "CarmeConfig.backend.new" "CarmeConfig.backend"
#-----------------------------------------------------------------------------------------------------------------------------------
