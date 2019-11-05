#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Helper script to strip information from CarmeConfig and create a clean CarmeConfig_blanco.
# Variables defined in DEFAULT_VARIABLES are not removed!
#-----------------------------------------------------------------------------------------------------------------------------------

CONFIG_FILE="/opt/Carme/CarmeConfig"
CONFIG_FILE_BLANCO="/opt/Carme/CarmeConfig_blanco"

DEFAULT_VARIABLES=(CARME_VERSION CARME_SCRIPT_PATH CARME_BACKEND_PATH CARME_MESSAGE_PATH CARME_FRONTEND_PATH CARME_SLURM_SCRIPTS_PATH CARME_SLURM_CONFIG_FILE CARME_SCRIPTS_PATH CARME_WEB_PATH CARME_ZABBIX_GRAPH_PATH)

#-----------------------------------------------------------------------------------------------------------------------------------

VARIABLE_ARRAY=()
VARIABLE_ARRAY_HELPER=()
for VARIABLE in `cat ${CONFIG_FILE}`;do
   if [[ "$VARIABLE" =~ ^CARME* ]]; then
     PURE_VARIABLE=${VARIABLE%%=*}
     VARIABLE_ARRAY_HELPER+=($PURE_VARIABLE)
   fi
done

for DEFAULT in ${DEFAULT_VARIABLES[@]};do
   VARIABLE_ARRAY_HELPER=("${VARIABLE_ARRAY_HELPER[@]/$DEFAULT}")
done
for ENTRY in "${VARIABLE_ARRAY_HELPER[@]}";do
    if [[ ! -z $ENTRY ]];then
      VARIABLE_ARRAY+=($ENTRY)
    fi
done
unset VARIABLE_ARRAY_HELPER
unset DEFAULT_VARIABLES

if [[ -f ${CONFIG_FILE_BLANCO} ]];then
  rm ${CONFIG_FILE_BLANCO}
fi
cp -p ${CONFIG_FILE} ${CONFIG_FILE_BLANCO}

for ENTRIES in "${VARIABLE_ARRAY[@]}";do
  if [[ "${ENTRIES}" =~ CARME_BACKEND_DEBUG|CARME_BACKEND_PORT|CARME_FRONTEND_DEBUG|CARME_HARDWARE_NUM_GPUS ]];then
    sed -i -e 's/'"${ENTRIES}"'=.*/'"${ENTRIES}"'=/g' ${CONFIG_FILE_BLANCO}
  elif [[ "${ENTRIES}" =~ CARME_PROXY_PATH|CARME_BASE_MOUNTS|CARME_FRONTEND_KEY ]];then
    sed -i -e 's/'"${ENTRIES}"'=\x27.*\x27/'"${ENTRIES}"'=\x27\x27/g' ${CONFIG_FILE_BLANCO}
  else
    sed -i -e 's/'"${ENTRIES}"'=".*"/'"${ENTRIES}"'=""/g' ${CONFIG_FILE_BLANCO}
  fi
done

