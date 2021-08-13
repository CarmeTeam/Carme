#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# simple script to display messages in terminals
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------


# display messages that are provided by carme --------------------------------------------------------------------------------------
# carme banner
echo -e "\033[1mWelcome to -----------------------------------\033[0m"
echo -e "\033[1m  ____   ___   _____  __  __  ____  \033[0m"
echo -e "\033[1m / __ \ / _ \ /  __ \|  \/  |/  __\ \033[0m"
echo -e "\033[1m| /  \// /_\ \| |_/ /|      || |__  \033[0m"
echo -e "\033[1m| |    |  _  ||    / | |\/| ||  __| \033[0m"
echo -e "\033[1m| \__/\| | | || |\ \ | |  | || |___ \033[0m"
echo -e "\033[1m \____/\_| |_|\_| \_|\_|  |_|\____/ \033[0m"
echo ""

# link to documentation
echo -e "\033[1mDocumentation --------------------------------\033[0m"
echo "https://carmeteam.github.io/Carme-Docu/UserDoc"
echo ""

# print job information
echo -e "\033[1mJob Information ------------------------------\033[0m"
echo "Job-ID|-Name: ${CARME_JOB_ID} | ${CARME_JOB_NAME}"
echo "Nodes:        ${CARME_NODES}"
if [[ -n "$(echo "${CARME_JOB_GPUS}" | tr ',' '\n' | wc -l)" ]];then
  echo "GPUs/Node:    $(echo "${CARME_JOB_GPUS}" | tr ',' '\n' | wc -l)"
fi
if [[ -n "${CARME_JOB_GPUS}" ]];then
  echo "GPU-ID(s):    ${CARME_JOB_GPUS}"
fi
echo "End-Time:   $(grep "^${CARME_JOB_ID}[[:space:]]${CARME_JOB_NAME}" .local/share/carme/job-log-dir/job-log.dat | awk '{print $6}')"
#-----------------------------------------------------------------------------------------------------------------------------------


# display cluster specific messages that are not part of carme ---------------------------------------------------------------------
CARME_LOCAL_MESSAGE_PATH="/home/.CarmeScripts/local-messages"
if [[ -d ${CARME_LOCAL_MESSAGE_PATH} ]];then
  mapfile -t CARME_LOCAL_MESSAGES < <(find "${CARME_LOCAL_MESSAGE_PATH}" -maxdepth 1 -type f)

  for MESSAGE in "${CARME_LOCAL_MESSAGES[@]}";do
    if [[ ${MESSAGE} == *".sh" ]]; then
      source "${MESSAGE}"
      echo ""
    elif [[ ${MESSAGE} == *".txt" ]]; then
      CARME_MESSAGE=$(<"${MESSAGE}")
      echo "${CARME_MESSAGE}"
      echo ""
    fi
  done
fi
#-----------------------------------------------------------------------------------------------------------------------------------
