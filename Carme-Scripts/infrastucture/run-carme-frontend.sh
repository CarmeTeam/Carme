#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to start or stop the frontend singularity container. It creates the apache logs folder and mounts all required folders
# inside the singularity image.
#
# Notes:
# This script has to be copied to the login-node and there in particular to the folder in which the frontend singularity image is
# located! Otherwise this script will not work!
#-----------------------------------------------------------------------------------------------------------------------------------

if [ ! "$BASH_VERSION" ]; then
    printf "${SETCOLOR}This is a bash-script. Please use bash to execute it!${NOCOLOR}\n\n"
    exit 137
fi

if [ ! $(whoami) = "root" ]; then
    printf "${SETCOLOR}you need root privileges to run this script${NOCOLOR}\n\n"
    exit 137
fi

IMAGE_NAME="carme-frontend"
INSTANCE_NAME="CarmeFrontend"
APACHE_LOGS_DIR="/var/log/Carme/Carme-Apache-Logs"
PROXY_ROUTES="/opt/Carme-Proxy-Routes"


if [ -f ${IMAGE_NAME}.simg ];then
  if [[ "$1" == "start" ]];then
    mkdir -p ${APACHE_LOGS_DIR}
				singularity instance start -B /opt/Carme/Carme-Frontend:/opt/Carme/Carme-Frontend -B ${APACHE_LOGS_DIR}:/opt/Carme-Apache-Logs -B ${PROXY_ROUTES}:/opt/traefik/routes ${IMAGE_NAME}.simg ${INSTANCE_NAME}
  elif [[ "$1" == "stop" ]];then
    singularity instance stop ${INSTANCE_NAME}
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

