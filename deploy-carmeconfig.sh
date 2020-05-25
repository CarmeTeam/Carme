#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# deployCarmeConfig.sh deploys the CarmeConfig into separate files
# - CarmeConfig.frontend
# - CarmeConfig.backend
# - CarmeConfig.container
#-----------------------------------------------------------------------------------------------------------------------------------
# USAGE: In order to run this script you have to be `root` and run it as `bash deployCarmeConfig.sh`.
#-----------------------------------------------------------------------------------------------------------------------------------
# COPYRIGHT: Fraunhofer ITWM, 2019
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
VARIABLES_PARAMETER_FILE="/opt/Carme/variables.conf"
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


# source needed variables /opt/Carme/CarmeConfig -----------------------------------------------------------------------------------
CARME_FRONTEND_PATH=$(get_variable CARME_FRONTEND_PATH)
[[ -z ${CARME_FRONTEND_PATH} ]] && die "CARME_FRONTEND_PATH not set"

CARME_SCRIPT_PATH=$(get_variable CARME_SCRIPT_PATH)
[[ -z ${CARME_SCRIPT_PATH} ]] && die "CARME_SCRIPT_PATH not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# source the variables that have to be imported from /opt/Carme/CarmeConfig --------------------------------------------------------
FRONTEND_VARIABLES=$(get_parameter FRONTEND_VARIABLES)
CONTAINER_VARIABLES=$(get_parameter CONTAINER_VARIABLES)
BACKEND_VARIABLES=$(get_parameter BACKEND_VARIABLES)
#-----------------------------------------------------------------------------------------------------------------------------------


# get date -------------------------------------------------------------------------------------------------------------------------
TODAY=$(date "+%d-%m-%Y")
#-----------------------------------------------------------------------------------------------------------------------------------


# define path where carme in installed ---------------------------------------------------------------------------------------------
CARME_BASE_PATH="/opt/Carme"
#-----------------------------------------------------------------------------------------------------------------------------------


# collect variables needed in the frontend -----------------------------------------------------------------------------------------
echo "collect variables needed in the webfrontend"

if [[ -f "${CARME_FRONTEND_PATH}/CarmeConfig.frontend" ]];then
  mv "${CARME_FRONTEND_PATH}/CarmeConfig.frontend" "${CARME_FRONTEND_PATH}/CarmeConfig.frontend_old" || die "cannot backup CarmeConfig.frontend"
  echo "saved previous CarmeConfig.frontend as CarmeConfig.frontend_old"
fi

echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Frontend Config
#
# WARNING: This file is generated automatically by deployCarmeConfig.sh. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > CarmeConfig.frontend

for VARIABLE in ${FRONTEND_VARIABLES};do
  grep "^${VARIABLE}=" "${CONFIG_FILE}" >> CarmeConfig.frontend
done


# change permissions of new CarmeConfig.frontend
chmod 600 CarmeConfig.frontend || die "cannot change file permissions of CarmeConfig.frontend"
echo "changed permission of CarmeConfig.frontend to 600"


# move new CarmeConfig.frontend CARME_FRONTEND_PATH
mv CarmeConfig.frontend "${CARME_FRONTEND_PATH}/CarmeConfig.frontend" || die "cannot move CarmeConfig.frontend to ${CARME_FRONTEND_PATH}"
echo "moved CarmeConfig.frontend to ${CARME_FRONTEND_PATH}"


# change ownership of CarmeConfig.frontend
chown www-data:www-data "${CARME_FRONTEND_PATH}/CarmeConfig.frontend"


# check modification date
MODIFYDATE_FRONTEND_CONFIG=$(date -r "${CARME_FRONTEND_PATH}"/CarmeConfig.frontend "+%d-%m-%Y")
[[ "${MODIFYDATE_FRONTEND_CONFIG}" != "${TODAY}" ]] && die "CarmeConfig.frontend not modified (last modification ${MODIFYDATE_FRONTEND_CONFIG})"
#-----------------------------------------------------------------------------------------------------------------------------------


# collect variables needed inside the containers -----------------------------------------------------------------------------------
echo ""
echo "collect variables needed inside the containers"

if [[ -f "${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container" ]];then
  mv "${CARME_SCRIPT_PATH}"/../InsideContainer/CarmeConfig.container "${CARME_SCRIPT_PATH}"/../InsideContainer/CarmeConfig.container_old  || die "cannot backup CarmeConfig.container"
  echo "saved previous CarmeConfig.container as CarmeConfig.container_old"
fi

echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Container Config
# 
# WARNING: This file is generated automatically by deployCarmeConfig.sh. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > CarmeConfig.container

for VARIABLE in ${CONTAINER_VARIABLES};do
  grep "^${VARIABLE}=" "${CONFIG_FILE}" >> CarmeConfig.container
done


# change permissions of new CarmeConfig.container
chmod 644 CarmeConfig.container || die "cannot change file permissions of CarmeConfig.container"
echo "changed permission of CarmeConfig.container to 644"


# move new CarmeConfig.container to CARME_SCRIPT_PATH/../InsideContainer
mv CarmeConfig.container "${CARME_SCRIPT_PATH}"/../InsideContainer/CarmeConfig.container || die "cannot move CarmeConfig.container ${CARME_SCRIPT_PATH}/../InsideContainer"
echo "moved CarmeConfig.container to ${CARME_SCRIPT_PATH}/../InsideContainer"


# check modification date
MODIFYDATE_CONTAINER_CONFIG=$(date -r "${CARME_SCRIPT_PATH}"/../InsideContainer/CarmeConfig.container "+%d-%m-%Y")
[[ "${MODIFYDATE_CONTAINER_CONFIG}" != "${TODAY}" ]] && die "${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container not modified (last modification ${MODIFYDATE_FRONTEND_CONFIG})"
#-----------------------------------------------------------------------------------------------------------------------------------


# collect variables needed in the backend ------------------------------------------------------------------------------------------
echo ""
echo "collect variables needed in the backend"


if [[ -f "${CARME_BASE_PATH}/CarmeConfig.backend" ]];then
  mv "${CARME_BASE_PATH}"/CarmeConfig.backend "${CARME_BASE_PATH}"/CarmeConfig.backend_old  || die "cannot backup CarmeConfig.backend"
  echo "saved previous CarmeConfig.backend as CarmeConfig.backend_old"
fi

echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Backend Config
#
# WARNING: This file is generated automatically by deployCarmeConfig.sh. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > "${CARME_BASE_PATH}"/CarmeConfig.backend

for VARIABLE in ${BACKEND_VARIABLES};do
  grep "^${VARIABLE}=" "${CONFIG_FILE}" >> "${CARME_BASE_PATH}"/CarmeConfig.backend
done


# change permissions of new CarmeConfig.backend
chmod 644 "${CARME_BASE_PATH}"/CarmeConfig.backend || die "cannot change file permissions of CarmeConfig.backend"
echo "changed permission of CarmeConfig.backend to 644"

MODIFYDATE_BACKEND_CONFIG=$(date -r "${CARME_BASE_PATH}"/CarmeConfig.backend "+%d-%m-%Y")
[[ "${MODIFYDATE_BACKEND_CONFIG}" != "${TODAY}" ]] && die "${CARME_BASE_PATH}/CarmeConfig.backend not modified (last modification ${MODIFYDATE_BACKEND_CONFIG})"
#-----------------------------------------------------------------------------------------------------------------------------------
