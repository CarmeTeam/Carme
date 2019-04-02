#!/bin/bash
# ---------------------------------------------- 
# Carme
# ----------------------------------------------
# deployCarmeConfig.sh - deploys Carme Configi
# to Frontend and Containers
#
# usage: ./deployCarmeConfig.sh PATH_TO_CARME_CONFIG
# see Carme development guide for documentation: 
# * Carme/Carme-Doc/DevelDoc/readme.md
#
# Copyright 2019 by Fraunhofer ITWM  
# License: http://open-carme.org/LICENSE.md 
# Contact: info@open-carme.org
# ---------------------------------------------  

source $1

echo "
#-------------------------------
# Carme Frontend Config
#
# WARNING: automatic generated file - do not edit!
#
# Change CarmeConfig and call deployCarmeConfig
#
#-------------------------------
" > CarmeConfig.frontend

grep FRONTEND CarmeConfig >> CarmeConfig.frontend

echo " 

#-------------------------------  
# Carme Container Config
# 
# WARNING: automatic generated file - do not edit!  
#
# Change CarmeConfig and call deployCarmeConfig  
#
#-------------------------------

" > CarmeConfig.container     

grep CONTAINER CarmeConfig >> CarmeConfig.container

chmod 700 CarmeConfig.frontend
chmod 755 CarmeConfig.container

cp CarmeConfig.frontend ${CARME_FRONTEND_PATH}/
chown www-data:www-data ${CARME_FRONTEND_PATH}/CarmeConfig.frontend

cp CarmeConfig.container ${CARME_SCRIPT_PATH}/../InsideContainer/

rm CarmeConfig.frontend CarmeConfig.container
