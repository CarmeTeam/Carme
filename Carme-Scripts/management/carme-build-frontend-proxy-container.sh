#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to build the frontend or proxy container
#
# WEBPAGE:   https://carmeteam.github.io/Carme/
# COPYRIGHT: Carme Team @Fraunhofer ITWM, 2021
# CONTACT:   dominik.strassel@itwm.fraunhofer.de
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# variables ------------------------------------------------------------------------------------------------------------------------
CARME_PATH="/opt/Carme"                                                                  # path to carme installation
PATH_TO_SCRIPTS_FOLDER="${CARME_PATH}/Carme-Scripts"                                     # path to the carme scripts folder

HELPER_FRONTEND_CONTAINER="Carme-ContainerImages/Carme-Frontend-Container/frontend"      # helper variable to create the frontend container
HELPER_PROXY_CONTAINER="Carme-ContainerImages/Carme-Proxy-Container/proxy"               # helper variable to create the proxy container
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
check_command singularity
#-----------------------------------------------------------------------------------------------------------------------------------


# import needed variables from CarmeConfig -----------------------------------------------------------------------------------------
CARME_HEADNODE_NAME=$(get_variable CARME_HEADNODE_NAME)

[[ -z ${CARME_HEADNODE_NAME} ]] && die "CARME_HEADNODE_NAME not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if node is headnode --------------------------------------------------------------------------------------------------------
if [[ "$(hostname -s)" -ne "${CARME_HEADNODE_NAME}" ]];then
  die "your are not on the headnode"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# functions ------------------------------------------------------------------------------------------------------------------------

function print_help (){
  echo "script to build the frontend or proxy container

Usage: bash carme-build-frontend-proxy-container.sh [arguments]

Arguments:
  --frontend                              start the backend service (on the headnode)
  --proxy                                 stop the backend service (on the headnode)

  -h or --help                            print this help and exit
"
  exit 0
}



function build_container () {

  local CONTAINER_NAME="${1}"
  local HELPER="${2}"
  local OLDPATH="$(pwd)"

  read -rp "Do you want to build a new ${CONTAINER_NAME} singularity container? [y/N] " RESP

  if [[ "${RESP}" = "y" ]];then

    cd "${CARME_PATH}"

    singularity build "${CONTAINER_NAME}.simg" "${HELPER}.recipe"

    [[ -f "${HELPER}.simg" ]] && mv "${HELPER}.simg" "${HELPER}.simg.bak"

    mv "${CONTAINER_NAME}.simg" "${HELPER}.simg"

    cd "${OLDPATH}"

  else

    echo "bye...bye..."

  fi

  exit 0

}


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
       shift
     ;;
     --frontend)
       build_container "frontend" "${HELPER_FRONTEND_CONTAINER}"
       shift
       shift
     ;;
     --proxy)
       build_container "proxy" "${HELPER_PROXY_CONTAINER}"
       shift
       shift
     ;;
     *)
      print_help
      shift
     ;;
   esac
  done

fi
#-----------------------------------------------------------------------------------------------------------------------------------

exit 0
