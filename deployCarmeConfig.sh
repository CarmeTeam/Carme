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


# default parameters ---------------------------------------------------------------------------------------------------------------
echo ""
SETCOLOR='\033[1;33m'
NOCOLOR='\033[0m'

CONFIG_PATH="/opt/Carme"
CONFIG_FILE="${CONFIG_PATH}/CarmeConfig"
VARIABLES_CONFIG_FILE="/opt/variables.conf"
TODAY=$(date "+%d-%m-%Y")
#-----------------------------------------------------------------------------------------------------------------------------------


# check if script is executed with bash --------------------------------------------------------------------------------------------
if [ ! "$BASH_VERSION" ]; then
  printf "${SETCOLOR}This is a bash-script. Please use bash to execute it!${NOCOLOR}\n\n"
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if user is root ------------------------------------------------------------------------------------------------------------
if [ ! $(whoami) = "root" ]; then
  printf "${SETCOLOR}you need root privileges to run this script${NOCOLOR}\n\n"
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to extract variables from another file ---------------------------------------------------------------------------
if [[ -f ${CONFIG_FILE} && -f ${VARIABLES_CONFIG_FILE} ]];then
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=${variable_value%#*}
    variable_value=${variable_value%#*}
    variable_value=$(echo "${variable_value}" | tr -d '"')
    echo ${variable_value}
  }
else
  printf "${SETCOLOR}no config-file found${NOCOLOR}\n"
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------

# source needed variables /opt/Carme/CarmeConfig -----------------------------------------------------------------------------------
CARME_FRONTEND_PATH=$(get_variable CARME_FRONTEND_PATH ${CONFIG_FILE})
CARME_SCRIPT_PATH=$(get_variable CARME_SCRIPT_PATH ${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------


# source the variables that have to be imported from /opt/Carme/CarmeConfig --------------------------------------------------------
VARIABLES_CONFIG_FILE="/opt/variables.conf"
FRONTEND_VARIABLES=$(get_variable FRONTEND_VARIABLES ${VARIABLES_CONFIG_FILE})
CONTAINER_VARIABLES=$(get_variable CONTAINER_VARIABLES ${VARIABLES_CONFIG_FILE})
BACKEND_VARIABLES=$(get_variable BACKEND_VARIABLES ${VARIABLES_CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------


# start to collect the variables from CarmeConfig and distribute them to the respective local configs ------------------------------
# collect variables needed in the frontend -----------------------------------------------------------------------------------------
echo "collect variables needed in the webfrontend"

echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Frontend Config
#
# WARNING: This file is generated automatically by deployCarmeConfig.sh. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > CarmeConfig.frontend

for VARIABLE in ${FRONTEND_VARIABLES};do
  grep "${VARIABLE}=" ${CONFIG_FILE} >> CarmeConfig.frontend
done

chmod 600 CarmeConfig.frontend
mv CarmeConfig.frontend ${CARME_FRONTEND_PATH}/CarmeConfig.frontend
chown www-data:www-data ${CARME_FRONTEND_PATH}/CarmeConfig.frontend

MODIFYDATE_FRONTEND_CONFIG=$(date -r ${CARME_FRONTEND_PATH}/CarmeConfig.frontend "+%d-%m-%Y")
if [[ ! -f "${CARME_FRONTEND_PATH}/CarmeConfig.frontend" ]];then
  echo "FATAL ERROR: ${CARME_FRONTEND_PATH}/CarmeConfig.frontend does not exist!"
  echo ""
  exit 137
fi

if [[ "${MODIFYDATE_FRONTEND_CONFIG}" != "${TODAY}" ]];then
  echo "FATAL ERROR: ${CARME_FRONTEND_PATH}/CarmeConfig.frontend was not modified!"
  echo "             (last modification ${MODIFYDATE_FRONTEND_CONFIG})"
  echo ""
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# collect variables needed inside the containers -----------------------------------------------------------------------------------
echo "collect variables needed inside the containers"

echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Container Config
# 
# WARNING: This file is generated automatically by deployCarmeConfig.sh. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > CarmeConfig.container     

for VARIABLE in ${CONTAINER_VARIABLES};do
  grep "${VARIABLE}=" ${CONFIG_FILE} >> CarmeConfig.container
done

chmod 644 CarmeConfig.container
mv CarmeConfig.container ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container

MODIFYDATE_CONTAINER_CONFIG=$(date -r ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container "+%d-%m-%Y")
if [[ ! -f "${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container" ]];then
  echo "FATAL ERROR: ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container does not exist!"
  echo ""
  exit 137
fi

if [[ "${MODIFYDATE_CONTAINER_CONFIG}" != "${TODAY}" ]];then
  echo "FATAL ERROR: ${CARME_SCRIPT_PATH}/../InsideContainer/CarmeConfig.container was not modified!"
  echo "             (last modification ${MODIFYDATE_FRONTEND_CONFIG})"
  echo ""
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# collect variables needed in the backend ------------------------------------------------------------------------------------------
echo "collect variables needed in the backend"

echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Backend Config
#
# WARNING: This file is generated automatically by deployCarmeConfig.sh. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > ${CONFIG_PATH}/CarmeConfig.backend

for VARIABLE in ${BACKEND_VARIABLES};do
  grep "${VARIABLE}=" ${CONFIG_FILE} >> ${CONFIG_PATH}/CarmeConfig.backend
done

chmod 644 ${CONFIG_PATH}/CarmeConfig.backend

MODIFYDATE_BACKEND_CONFIG=$(date -r ${CONFIG_PATH}/CarmeConfig.backend "+%d-%m-%Y")
if [[ ! -f "${CONFIG_PATH}/CarmeConfig.backend" ]];then
  echo "FATAL ERROR: ${CONFIG_PATH}/CarmeConfig.backend does not exist!"
  echo ""
  exit 137
fi

if [[ "${MODIFYDATE_BACKEND_CONFIG}" != "${TODAY}" ]];then
  echo "FATAL ERROR: ${CONFIG_PATH}/CarmeConfig.backend was not modified!"
  echo "             (last modification ${MODIFYDATE_BACKEND_CONFIG})"
  echo ""
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------

echo ""
exit 0

