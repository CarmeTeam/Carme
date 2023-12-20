#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to set node statuses in the database (e.g. as a cronjob)
#
# WEBPAGE:   https://carmeteam.github.io/Carme/
# COPYRIGHT: Carme Team @Fraunhofer ITWM, 2023
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


# define path to carme installation ------------------------------------------------------------------------------------------------
CARME_DIR="/opt/Carme"
CONF_PATH="/etc/carme"

PATH_TO_SCRIPTS_FOLDER="${CARME_DIR}/Carme-Scripts"

CONFIG_FILE="${CONF_PATH}/CarmeConfig"
FRONTEND_CONFIG="${CONF_PATH}/CarmeConfig.frontend"
NODE_CONFIG="${CONF_PATH}/CarmeConfig.node"
BACKEND_CONFIG="${CONF_PATH}/CarmeConfig.backend"

VARIABLES_PARAMETER_FILE="${PATH_TO_SCRIPTS_FOLDER}/management/variables.conf"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if config file exists ------------------------------------------------------------------------------------------------------
[[ ! -f "${CONFIG_FILE}" ]] && die "carme config not found in '${CONF_PATH}'."
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
if [[ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ]];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  die "'${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh' not found."
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if bash is used to execute the script --------------------------------------------------------------------------------------
is_bash
#-----------------------------------------------------------------------------------------------------------------------------------


# check if root executes this script -----------------------------------------------------------------------------------------------
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command grep
check_command ssh
check_command hostname
#-----------------------------------------------------------------------------------------------------------------------------------


# import the needed variables from CarmeConfig -------------------------------------------------------------------------------------
CARME_DB_USER=$(get_variable CARME_DB_USER)
CARME_DB_PW=$(get_variable CARME_DB_PW)
CARME_DB_DB=$(get_variable CARME_DB_DB)
CARME_HEADNODE_NAME=$(get_variable CARME_HEADNODE_NAME)
CARME_NODES_LIST=$(get_variable CARME_NODES_LIST)

[[ -z ${CARME_DB_USER} ]] && die "CARME_DB_USER not set"
[[ -z ${CARME_DB_PW} ]] && die "CARME_DB_PW not set"
[[ -z ${CARME_DB_DB} ]] && die "CARME_DB_DB not set"
[[ -z ${CARME_HEADNODE_NAME} ]] && die "CARME_HEADNODE_NAME not set"
[[ -z ${CARME_NODES_LIST} ]] && die "CARME_NODES_LIST not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if node is headnode --------------------------------------------------------------------------------------------------------
[[ "$(hostname -s)" != "${CARME_HEADNODE_NAME}" ]] && die "this is not the headnode ('${CARME_HEADNODE_NAME}') specified in '${CONFIG_FILE}'."
#-----------------------------------------------------------------------------------------------------------------------------------


# check if variables file is available ---------------------------------------------------------------------------------------------
[[ ! -f ${VARIABLES_PARAMETER_FILE} ]] && die "'${VARIABLES_PARAMETER_FILE}' not found"
#-----------------------------------------------------------------------------------------------------------------------------------


# set database password -----------------------------------------------------------------------------------------------------
export MYSQL_PWD=${CARME_DB_PW}
#-----------------------------------------------------------------------------------------------------------------------------------


# set the statuses of nodes --------------------------------------------------------------------------------------------------------
for COMPUTE_NODE in ${CARME_NODES_LIST}; do
  STATUS=1
  NUMACC=0

  if [ $STATUS -ne 0 ]; then
    if ! ssh $COMPUTE_NODE true 2> /dev/null; then
      STATUS=0
    fi
  fi

  if [ $STATUS -ne 0 ]; then
    if ! NUMACC=$(ssh $COMPUTE_NODE nvidia-smi | grep '%' | wc -l); then
      STATUS=0
    fi
  fi

  if [ $STATUS -ne 0 ]; then
    if ! sinfo -N -n $COMPUTE_NODE -t 'idle,mix,alloc' | grep $COMPUTE_NODE > /dev/null; then
      STATUS=0
    fi
  fi

  #echo "NODE   : $COMPUTE_NODE"
  #echo "STATUS : $STATUS"
  #echo "NUMACC : $NUMACC"
  #echo
  
  mysql --user ${CARME_DB_USER} ${CARME_DB_DB} -e "update projects_accelerator set node_status='$STATUS' where node_name='$COMPUTE_NODE'"
  mysql --user ${CARME_DB_USER} ${CARME_DB_DB} -e "update projects_accelerator set num_per_node='$NUMACC' where node_name='$COMPUTE_NODE'"
  #mysql --user ${CARME_DB_USER} ${CARME_DB_DB} -e "select * from projects_accelerator"
done
#-----------------------------------------------------------------------------------------------------------------------------------

exit 0
