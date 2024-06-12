#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# This script creates and or deploys the different CarmeConfig files (*.backend, *,frontend, *.node)
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
CONF_PATH="/etc/carme"

PATH_TO_SCRIPTS_FOLDER="${CARME_DIR}/Carme-Scripts"

CONFIG_FILE="${CONF_PATH}/CarmeConfig"
FRONTEND_CONFIG="${CONF_PATH}/CarmeConfig.frontend"
NODE_CONFIG="${CONF_PATH}/CarmeConfig.node"
BACKEND_CONFIG="${CONF_PATH}/CarmeConfig.backend"

VARIABLES_PARAMETER_FILE="${PATH_TO_SCRIPTS_FOLDER}/management/variables.conf"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if config file exists ------------------------------------------------------------------------------------------------------
[[ ! -f "${CONFIG_FILE}" ]] && die "carme config not found in '${CONF_PATH}'."
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
if [[ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ]];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  die "'${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh' not found."
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if bash is used to execute the script --------------------------------------------------------------------------------------
is_bash
#-----------------------------------------------------------------------------------------------------------------------------------


# check if root executes this script -----------------------------------------------------------------------------------------------
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command grep
check_command ssh
check_command scp
check_command hostname
#-----------------------------------------------------------------------------------------------------------------------------------


# import the needed variables from CarmeConfig -------------------------------------------------------------------------------------
CARME_HEADNODE_NAME=$(get_variable CARME_HEADNODE_NAME)
CARME_LOGINNODE_NAME=$(get_variable CARME_LOGINNODE_NAME)
CARME_NODES_LIST=$(get_variable CARME_NODES_LIST)

[[ -z ${CARME_HEADNODE_NAME} ]] && die "CARME_HEADNODE_NAME not set"
[[ -z ${CARME_LOGINNODE_NAME} ]] && die "CARME_LOGINNODE_NAME not set"
[[ -z ${CARME_NODES_LIST} ]] && die "CARME_NODES_LIST not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if node is headnode --------------------------------------------------------------------------------------------------------
[[ "$(hostname -s)" != "${CARME_HEADNODE_NAME}" ]] && die "this is not the headnode ('${CARME_HEADNODE_NAME}') specified in '${CONFIG_FILE}'."
#-----------------------------------------------------------------------------------------------------------------------------------


# check if variables file is available ---------------------------------------------------------------------------------------------
[[ ! -f ${VARIABLES_PARAMETER_FILE} ]] && die "'${VARIABLES_PARAMETER_FILE}' not found"
#-----------------------------------------------------------------------------------------------------------------------------------


# define help message --------------------------------------------------------------------------------------------------------------
function print_help (){
  echo "script to create and or deploy the different CarmeConfig files

Webpage: https://carmeteam.github.io/Carme/

Usage: bash create-deploy-carmeconfig.sh [arguments]

Arguments:
  --create                                create CarmeConfig.backend, *.frontend and *.node
  --deploy                                deploy CarmeConfig.backend, *.frontend and *.node

  -h or --help                            print this help and exit
"
  exit 0
}
#-----------------------------------------------------------------------------------------------------------------------------------


# functions ------------------------------------------------------------------------------------------------------------------------

function create_frontend_config () {
# function to collect variables needed in the frontend

  local VARIABLE

  echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Frontend Config
#
# WARNING: This file is generated automatically. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > "${FRONTEND_CONFIG}"


  for VARIABLE in ${FRONTEND_VARIABLES};do
    grep "^${VARIABLE}=" "${CONFIG_FILE}" >> "${FRONTEND_CONFIG}"
  done


  if [[ "${WWW_DATA_USER}" == "true" && "${WWW_DATA_GROUP}" == "true" ]];then

    # change ownership of CarmeConfig.frontend
    chown www-data:www-data "${FRONTEND_CONFIG}"

    # change permissions of new CarmeConfig.frontend
    chmod 600 "${FRONTEND_CONFIG}" || die "cannot change file permissions of ${FRONTEND_CONFIG}"

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
    chmod 644 "${FRONTEND_CONFIG}" || die "cannot change file permissions of ${FRONTEND_CONFIG}"

  fi

}


function create_node_config () {
# function to collect variables needed on the compute nodes

  local VARIABLE

  echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Node Config
# 
# WARNING: This file is generated automatically. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > "${NODE_CONFIG}"


  for VARIABLE in ${CONTAINER_VARIABLES};do
    grep "^${VARIABLE}=" "${CONFIG_FILE}" >> "${NODE_CONFIG}"
  done


  # change permissions of new CarmeConfig.node
  chmod 644 "${NODE_CONFIG}" || die "cannot change file permissions of ${NODE_CONFIG}"

}


function create_backend_config () {
# function to collect variables needed in the backend

  local VARIABLE

  echo "
#-----------------------------------------------------------------------------------------------------------------------------------
# Carme Backend Config
#
# WARNING: This file is generated automatically. Do not edit manually!
#-----------------------------------------------------------------------------------------------------------------------------------
" > "${BACKEND_CONFIG}"


  for VARIABLE in ${BACKEND_VARIABLES};do
    grep "^${VARIABLE}=" "${CONFIG_FILE}" >> "${BACKEND_CONFIG}"
  done


  # change permissions of new CarmeConfig.backend
  chmod 644 "${BACKEND_CONFIG}" || die "cannot change file permissions of ${BACKEND_CONFIG}"

}


function backup_old_config () {
# function to backup possible existing config files (on the headnode)

  local HELPER="${1}"

  if [[ -f "${HELPER}" ]];then
    mv "${HELPER}" "${HELPER}.bak"
    echo "WARNING: '${HELPER}' stored as '${HELPER}.bak'"
  fi

}


function get_parameter () {
# define function to extract parameters from another file

  local PARAMETER

  PARAMETER=$(grep --color=never -Po "^${1}=\K.*" "${VARIABLES_PARAMETER_FILE}")
  PARAMETER=$(echo "${PARAMETER}" | tr -d '"')
  echo "${PARAMETER}"

}
#-----------------------------------------------------------------------------------------------------------------------------------


# main -----------------------------------------------------------------------------------------------------------------------------

if [[ ${#} -eq 0 ]];then

  print_help

else

  while [[ ${#} -gt 0 ]];do
    KEY="${1}"
    case ${KEY} in
     -h|--help)
       print_help
       shift
     ;;
     --create)
       CREATE_CONF="true"
       shift
     ;;
     --deploy)
       DEPLOY_CONF="true"
       shift
     ;;
     *)
      print_help
      shift
     ;;
   esac
  done

fi


if [[ "${CREATE_CONF}" == "true" ]];then

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


  # import the respective variables for the different CarmeConfig files
  FRONTEND_VARIABLES=$(get_parameter FRONTEND_VARIABLES)
  CONTAINER_VARIABLES=$(get_parameter CONTAINER_VARIABLES)
  BACKEND_VARIABLES=$(get_parameter BACKEND_VARIABLES)


  # backup existing config files
  backup_old_config "${FRONTEND_CONFIG}"
  backup_old_config "${NODE_CONFIG}"
  backup_old_config "${BACKEND_CONFIG}"


  # creaste new config files
  create_frontend_config
  create_node_config
  create_backend_config

fi


if [[ "${DEPLOY_CONF}" == "true" ]];then

  if [[ "$(hostname -s)" != "${CARME_LOGINNODE_NAME}" ]];then
    ssh -o LogLevel=QUIET "${CARME_LOGINNODE_NAME}" -t "mkdir -p ${CONF_PATH}"
    scp -o LogLevel=QUIET -p "${FRONTEND_CONFIG}" "${CARME_LOGINNODE_NAME}:${FRONTEND_CONFIG}"
    if [[ "${WWW_DATA_USER}" == "true" && "${WWW_DATA_GROUP}" == "true" ]];then
      ssh -o LogLevel=QUIET "${CARME_LOGINNODE_NAME}" -t "chown www-data:www-data ${FRONTEND_CONFIG}"
    fi
  fi


  for COMPUTE_NODE in ${CARME_NODES_LIST}; do
    ssh -o LogLevel=QUIET "${COMPUTE_NODE}" -t "mkdir -p ${CONF_PATH}"
    scp -o LogLevel=QUIET -p "${NODE_CONFIG}" "${COMPUTE_NODE}:${NODE_CONFIG}"
  done

fi
#-----------------------------------------------------------------------------------------------------------------------------------

exit 0
