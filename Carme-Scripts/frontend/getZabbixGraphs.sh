#!/bin/bash
# ----------------------------------------------
# Carme                                         
# ----------------------------------------------
# getZabbixGraphs.sh - get predefinde graphs from Zabbix
# 
# usage: getZabbixGraphs
#                                               
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#                                                   
# Copyright 2019 by Fraunhofer ITWM                 
# License: http://open-carme.org/LICENSE.md         
# Contact: info@open-carme.org                      
# ---------------------------------------------   

CLUSTER_DIR="/opt/Carme"
CONFIG_FILE="CarmeConfig"

SETCOLOR='\033[1;33m'
NOCOLOR='\033[0m'
#-----------------------------------------------------------------------------------------------------------------------------------
if [ -f $CLUSTER_DIR/$CONFIG_FILE ]; then
  function get_variable () {
    variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}")
    variable_value=$(echo "$variable_value" | tr -d '"')
    echo $variable_value
  }
else
  printf "${SETCOLOR}no config-file found in $CLUSTER_DIR${NOCOLOR}\n"
  exit 200
fi

#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables
CARME_NETWORK_BASE=$(get_variable CARME_NETWORK_BASE $CLUSTER_DIR/${CONFIG_FILE})
CARME_ZABBIX_GRAPH_PATH=$(get_variable CARME_ZABBIX_GRAPH_PATH $CLUSTER_DIR/${CONFIG_FILE})
#-----------------------------------------------------------------------------------------------------------------------------------

CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE="/opt/zabbix-graphs"
mkdir -p ${CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE}

#-----------------------------------------------------------------------------------------------------------------------------------

wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/admin_1.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=983\&period=604800\&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/admin_2.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=983\&period=43200\&width=800

wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}11.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=993&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}12.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1002&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}13.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1037&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}14.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=662&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}15.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1014&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}16.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=739&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}17.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=747&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}18.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=743&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}19.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=760&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}20.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=801&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}21.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=814&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}22.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=842&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}23.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=855&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}24.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=868&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}25.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=881&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_mem_${CARME_NETWORK_BASE}26.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=894&period=36000&width=800

wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}11.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=994&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}12.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1003&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}13.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1038&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}14.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=663&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}15.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1015&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}16.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=740&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}17.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=748&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}18.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=744&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}19.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=761&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}20.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=802&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}21.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=815&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}22.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=843&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}23.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=856&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}24.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=869&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}25.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=882&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_mem_${CARME_NETWORK_BASE}26.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=895&period=36000&width=800

wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}11.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=995&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}12.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1004&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}13.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1039&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}14.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=957&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}15.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1016&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}16.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=977&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}17.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=959&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}18.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=961&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}19.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=951&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}20.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=955&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}21.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=967&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}22.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=953&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}23.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=963&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}24.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=971&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}25.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=975&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_0_use_${CARME_NETWORK_BASE}26.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=979&period=36000&width=800 

wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}11.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=996&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}12.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1005&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}13.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1040&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}14.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=958&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}15.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=1017&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}16.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=978&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}17.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=960&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}18.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=962&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}19.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=952&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}20.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=956&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}21.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=968&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}22.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=954&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}23.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=964&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}24.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=972&period=36000&width=800
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}25.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=976&period=36000&width=800 
wget -o tmp -O $CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE/GPU_1_use_${CARME_NETWORK_BASE}26.png ${CARME_NETWORK_BASE}1:8383/chart2.php?graphid=980&period=36000&width=800

sleep 10
cp -v ${CARME_FRONTEND_ZABBIX_GRAPHS_STORAGE}/* ${CARME_ZABBIX_GRAPH_PATH}/
