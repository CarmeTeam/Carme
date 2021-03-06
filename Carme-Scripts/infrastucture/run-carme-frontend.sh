#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to start or stop the frontend singularity container. It creates the apache logs folder and mounts all required folders
# inside the singularity image.
#
# Notes:
# This script has to be copied to the login-node and there in particular to the folder in which the frontend singularity image is
# located! Otherwise this script will not work!
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# check if bash is used to execute the script --------------------------------------------------------------------------------------
[[ ! "$BASH_VERSION" ]] && die "This is a bash-script. Please use bash to execute it!"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if root executes this script -----------------------------------------------------------------------------------------------
[[ ! "$(whoami)" = "root" ]] && die "you need root privileges to run this script"
#-----------------------------------------------------------------------------------------------------------------------------------


# define paramters -----------------------------------------------------------------------------------------------------------------
IMAGE_NAME="carme-frontend"
INSTANCE_NAME="CarmeFrontend"
APACHE_LOGS_DIR="/var/log/Carme/Carme-Apache-Logs"
PROXY_ROUTES_DIR="/opt/Carme-Proxy-Routes"
CARME_FRONTEND_DIR="/opt/Carme/Carme-Frontend"
#-----------------------------------------------------------------------------------------------------------------------------------


if [ -f ${IMAGE_NAME}.simg ];then
  if [[ "$1" == "start" ]];then

    mkdir -p ${APACHE_LOGS_DIR}

    echo "starting singularity instance ${INSTANCE_NAME}"
    echo "(image: ${IMAGE_NAME}.simg)"
    singularity instance start -B ${CARME_FRONTEND_DIR}:/opt/Carme/Carme-Frontend -B ${APACHE_LOGS_DIR}:/opt/Carme-Apache-Logs -B ${PROXY_ROUTES_DIR}:/opt/traefik/routes ${IMAGE_NAME}.simg ${INSTANCE_NAME}

  elif [[ "$1" == "stop" ]];then

    FRONTEND_PID=$(singularity instance list | grep "${INSTANCE_NAME}\s" | awk '{print $2}')

    echo "stopping singularity instance ${INSTANCE_NAME} (PID: ${FRONTEND_PID})"
    singularity instance stop ${INSTANCE_NAME}
    tail --pid="${FRONTEND_PID}" -f /dev/null

  else

    echo "argument can only be"
    echo "start == start apache2 for ${INSTANCE_NAME}"
    echo "stop == stop apache2 for ${INSTANCE_NAME}"

  fi

else

  echo "This script has to be in the same folder as the Carme frontend image!"
  echo "Please copy this script to this folder. Note that this folder should"
  echo "be located on the CARME_LOGIN_NODE"

fi
