# ----------------------------------------------  
# Carme
# ----------------------------------------------
# createAndDeployUserCarts.sh - creates user certs
# useage:  createUserCert UserLogin 
# see Carme development guide for documentation: 
# * Carme/Carme-Doc/DevelDoc/readme.md  
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md  
# Contact: info@open-carme.org 
# --------------------------------------------- 
#!/bin/bash                  
CLUSTER_DIR="../../"
CONFIG_FILE="CarmeConfig"

SETCOLOR='\033[1;33m'
NOCOLOR='\033[0m'

if [ -f $CLUSTER_DIR/$CONFIG_FILE ]; then
								    source $CLUSTER_DIR/$CONFIG_FILE
else
												printf "${SETCOLOR}no config-file found in $CLUSTER_DIR${NOCOLOR}\n"
												exit 137
fi

openssl genrsa -out $1.key 4096
openssl req -new -key $1.key -out $1.csr -days 3650 -subj "/C=$CARME_SSL_C/ST=$CARME_SSL_ST/L=$CARME_SSL_L/O=$CARME_SSL_O/OU=$CARME_SSL_OU/CN=$1/emailAddress=$1$CARME_SSL_EMAIL_BASE" -passin pass:""
#NOTE: backend key and cert must be in this directory
openssl x509 -req -in $1.csr -CA backend.crt -CAkey backend.key -set_serial 01 -out $1.crt 
