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

IMAGE_NAME="carme-proxy"
INSTANCE_NAME="CarmeProxy"
PROXY_LOGS_DIR="/var/log/Carme/Carme-Traefik-Logs"
PROXY_ROUTES_DIR="/opt/Carme-Proxy-Routes"
CARME_PROXY_DIR="/opt/Carme/Carme-Proxy"

if [ -f ${IMAGE_NAME}.simg ];then
  if [[ "$1" == "start" ]];then
    mkdir -p ${PROXY_LOGS_DIR}
    mkdir -p ${PROXY_ROUTES_DIR}/dynamic
				chmod 777 ${PROXY_ROUTES_DIR}/dynamic
				chown -R www-data:www-data ${PROXY_ROUTES_DIR}
				chown -R www-data:www-data ${PROXY_LOGS_DIR}
				if [[ ! -f "${PROXY_ROUTES_DIR}/static.toml" ]];then
      ln -s ${CARME_PROXY_DIR}/traefik-conf/static.toml ${PROXY_ROUTES_DIR}/static.toml
				fi
				singularity instance start -B ${CARME_PROXY_DIR}:/opt/Carme/Carme-Proxy -B ${PROXY_LOGS_DIR}:/opt/Carme-Traefik-Logs -B ${PROXY_ROUTES_DIR}:/opt/traefik/routes ${IMAGE_NAME}.simg ${INSTANCE_NAME}
  elif [[ "$1" == "stop" ]];then
    PROXY_PID=$(singularity instance list | grep "${INSTANCE_NAME}\s" | awk '{print $2}')
    singularity instance stop ${INSTANCE_NAME}
				tail --pid=${PROXY_PID} -f /dev/null
  else
    echo "argument can only be"
    echo "start == start traefik for ${INSTANCE_NAME}"
    echo "stop == stop traefik for ${INSTANCE_NAME}"
  fi
else
  echo "This script has to be in the same folder as the Carme proxy image!"
  echo "Please copy this script to this folder. Note that this folder should"
  echo "be located on the CARME_LOGIN_NODE!"
fi

