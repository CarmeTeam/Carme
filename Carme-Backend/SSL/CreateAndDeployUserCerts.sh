#!/bin/bash
# ----------------------------------------------------------------------------------------------------------------------------------
# Carme
# ----------------------------------------------------------------------------------------------------------------------------------
# createAndDeployUserCarts.sh - creates user certs
#
# useage:  createAndDeployUserCert UserLogin
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/readme.md
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# Contact: info@open-carme.org
# ----------------------------------------------------------------------------------------------------------------------------------

# default parameters ---------------------------------------------------------------------------------------------------------------
printf "\n"
CLUSTER_DIR="/opt/Carme"
CONFIG_FILE="CarmeConfig"
SETCOLOR='\033[1;33m'
NOCOLOR='\033[0m'
#-----------------------------------------------------------------------------------------------------------------------------------

if [ ! "$BASH_VERSION" ]; then
  printf "${SETCOLOR}This is a bash-script. Please use bash to execute it!${NOCOLOR}\n\n"
  exit 137
fi

if [ ! $(whoami) = "root" ]; then                                                                                                                                                         
  printf "${SETCOLOR}you need root privileges to run this script${NOCOLOR}\n\n"
  exit 137
fi

if [ -f $CLUSTER_DIR/$CONFIG_FILE ]; then
  source ${CLUSTER_DIR}/${CONFIG_FILE} 
else
  printf "${SETCOLOR}no config-file found in $CLUSTER_DIR${NOCOLOR}\n"
  exit 137 
fi

if [ ! -f backend.crt -a ! -f backend.key ]; then
  printf "${SETCOLOR}backend.crt and backend.key have to be in this directory${NOCOLOR}\n"
  exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------

read -p "Do you want to create a new user certificate (validity 10 years)? [y/N] " RESP
if [ "$RESP" = "y" ]; then
  printf "\n"

  read -p "enter ldap-username(s) of users that need a new certificate [multiple users separated by space] " CLUSTER_USER_HELPER
  printf "\n"
  for CLUSTER_USER in $CLUSTER_USER_HELPER; do

    # determine user group
    CLUSTER_USER_GROUP=$(id -gn $CLUSTER_USER)
    echo "creating certs for ${CLUSTER_USER}:${CLUSTER_USER_GROUP}"

    echo $CARME_SSL_C $CARME_SSL_ST $CARME_SSL_L $CARME_SSL_O ${CARME_SSL_OU}

    # create new user keys    
    openssl genrsa -out ${CLUSTER_USER}.key 4096 
    openssl req -new -key ${CLUSTER_USER}.key -out ${CLUSTER_USER}.csr -days 3652 -subj "/C=$CARME_SSL_C/ST=$CARME_SSL_ST/L=$CARME_SSL_L/O=$CARME_SSL_O/OU=${CARME_SSL_OU}/CN=${CLUSTER_USER}/emailAddress=${CLUSTER_USER}${CARME_SSL_EMAIL_BASE}" -passin pass:"" 
    openssl x509 -req -days 3652 -in ${CLUSTER_USER}.csr -CA backend.crt -CAkey backend.key -set_serial 01 -out ${CLUSTER_USER}.crt

    # change ownership of new certificates
    chown ${CLUSTER_USER}:${CLUSTER_USER_GROUP} ${CLUSTER_USER}.crt
    chown ${CLUSTER_USER}:${CLUSTER_USER_GROUP} ${CLUSTER_USER}.csr
    chown ${CLUSTER_USER}:${CLUSTER_USER_GROUP} ${CLUSTER_USER}.key
    
    # move new certificates to /home/$USER/.carme
    CERT_STORE="/home/${CLUSTER_USER}/.carme/"
    if [ ! -d ${CERT_STORE} ]; then
      mkdir ${CERT_STORE}
    fi
    mv -v ${CLUSTER_USER}.crt ${CERT_STORE}/${CLUSTER_USER}.crt
    mv -v ${CLUSTER_USER}.csr ${CERT_STORE}/${CLUSTER_USER}.csr
    mv -v ${CLUSTER_USER}.key ${CERT_STORE}/${CLUSTER_USER}.key
  done
  printf "\n"
else
  printf "Bye Bye...\n\n"
fi

#-----------------------------------------------------------------------------------------------------------------------------------

exit 0

