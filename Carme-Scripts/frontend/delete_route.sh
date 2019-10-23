#!/bin/bash
# ----------------------------------------------------------------------------------------------------------------------------------
# Carme
# ----------------------------------------------------------------------------------------------------------------------------------
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
# ----------------------------------------------------------------------------------------------------------------------------------

function get_variable () {
  variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
  variable_value=${variable_value%#*}
  variable_value=$(echo "$variable_value" | tr -d '"')
  echo $variable_value
}
CARME_PROXY_PATH=$(get_variable CARME_PROXY_PATH $CLUSTER_DIR/${CONFIG_FILE})

#-----------------------------------------------------------------------------------------------------------------------------------

touch ${CARME_PROXY_PATH}/routes/dynamic/test
sleep 10
chmod 777 ${CARME_PROXY_PATH}/routes/dynamic/* 
rm ${CARME_PROXY_PATH}/routes/dummy.toml 
touch ${CARME_PROXY_PATH}/routes/dummy.toml
