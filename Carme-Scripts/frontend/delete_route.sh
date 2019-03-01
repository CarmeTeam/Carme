#!/bin/bash
# ----------------------------------------------
# Carme                                         
# ----------------------------------------------
# delete_route.sh - deletes dummy proxy                                                                                                                                                                    
# 
# usage: delete_route
#                                               
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#                                                   
# Copyright 2019 by Fraunhofer ITWM                 
# License: http://open-carme.org/LICENSE.md         
# Contact: info@open-carme.org                      
# ---------------------------------------------   

source ../../CarmeConfig

touch ${CARME_PROXY_PATH}/routes/dynamic/test
sleep 10
chmod 777 ${CARME_PROXY_PATH}/routes/dynamic/* 
rm ${CARME_PROXY_PATH}/routes/dummy.toml 
touch ${CARME_PROXY_PATH}/routes/dummy.toml
