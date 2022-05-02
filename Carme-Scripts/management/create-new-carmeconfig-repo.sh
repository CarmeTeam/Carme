#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# helper script to strip information from 'CarmeConfig' and create a new clean 'CarmeConfig.repo.new' in '/tmp'
# variables defined in DEFAULT_VARIABLES are not removed in 'CarmeConfig.repo.new'
#
# COPYRIGHT: Fraunhofer ITWM, 2021
# LICENCE: http://open-carme.org/LICENSE.md 
# CONTACT: info@open-carme.org
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# variables ------------------------------------------------------------------------------------------------------------------------
PATH_TO_SCRIPTS_FOLDER="/opt/Carme/Carme-Scripts"

CONFIG_FILE="/etc/carme/CarmeConfig"
CONFIG_FILE_BLANCO_NEW="/tmp/CarmeConfig.repo.new"

DEFAULT_VARIABLES=("CARME_VERSION" "CARME_BACKEND_PATH" "CARME_FRONTEND_PATH" "CARME_SLURM_CONFIG_FILE" "CARME_SCRIPTS_PATH" "CARME_TMPDIR")
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
if [[ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ]];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  die "carme-basic-bash-functions.sh not found but needed"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# some basic checks before we continue ---------------------------------------------------------------------------------------------
# check if bash is used to execute the script
is_bash

# check if root executes this script
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# read variables from CarmeConfig in an array and substract the default variables --------------------------------------------------
VARIABLE_ARRAY=()
VARIABLE_ARRAY_HELPER=()

while IFS= read -r VARIABLE
do
  if [[ "${VARIABLE}" =~ ^CARME* ]]; then
    PURE_VARIABLE=${VARIABLE%%=*}
    VARIABLE_ARRAY_HELPER+=("${PURE_VARIABLE}")
  fi
done < <(grep -v '^ *#' < ${CONFIG_FILE})


for DEFAULT in "${DEFAULT_VARIABLES[@]}";do
  VARIABLE_ARRAY_HELPER=("${VARIABLE_ARRAY_HELPER[@]/${DEFAULT}}")
done


for ENTRY in "${VARIABLE_ARRAY_HELPER[@]}";do
  [[ -n ${ENTRY} ]] && VARIABLE_ARRAY+=("${ENTRY}")
done

unset VARIABLE_ARRAY_HELPER
unset DEFAULT_VARIABLES
#-----------------------------------------------------------------------------------------------------------------------------------


# copy the existing CarmeConfig to CarmeConfig_blanco.new --------------------------------------------------------------------------
cp -p "${CONFIG_FILE}" "${CONFIG_FILE_BLANCO_NEW}"
echo "copied '${CONFIG_FILE}' to '${CONFIG_FILE_BLANCO_NEW}'"
#-----------------------------------------------------------------------------------------------------------------------------------


# delete non default values in CarmeConfig_blanco.new ------------------------------------------------------------------------------
echo "stripping the set non default variable values from '${CONFIG_FILE_BLANCO_NEW}'"
for ENTRIES in "${VARIABLE_ARRAY[@]}";do
  if [[ "${ENTRIES}" =~ CARME_BACKEND_PORT|CARME_FRONTEND_DEBUG ]];then
    sed -i -e 's/'"${ENTRIES}"'=.*/'"${ENTRIES}"'=/g' ${CONFIG_FILE_BLANCO_NEW}
  elif [[ "${ENTRIES}" =~ CARME_PROXY_PATH|CARME_FRONTEND_KEY ]];then
    sed -i -e 's/'"${ENTRIES}"'=\x27.*\x27/'"${ENTRIES}"'=\x27\x27/g' ${CONFIG_FILE_BLANCO_NEW}
  else
    sed -i -e 's/'"${ENTRIES}"'=".*"/'"${ENTRIES}"'=""/g' ${CONFIG_FILE_BLANCO_NEW}
  fi
done
#-----------------------------------------------------------------------------------------------------------------------------------

echo "created '${CONFIG_FILE_BLANCO_NEW}'"
