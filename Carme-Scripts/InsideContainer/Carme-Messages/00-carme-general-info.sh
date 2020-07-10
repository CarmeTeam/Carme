#!/bin/bash

# carme banner
echo -e "\033[1mWelcome to -----------------------------------\033[0m"
echo -e "\033[1m _____   ___   _____  __  __  ____ \033[0m"
echo -e "\033[1m/  __ \ / _ \ | ___ \|  \/  ||  __|\033[0m"
echo -e "\033[1m| /  \// /_\ \| |_/ /|      || |__ \033[0m"
echo -e "\033[1m| |    |  _  ||    / | |\/| ||  __|\033[0m"
echo -e "\033[1m| \__/\| | | || |\ \ | |  | || |___\033[0m"
echo -e "\033[1m \____/\_| |_/\_| \_|\_|  |_/\____/\033[0m"
echo ""

# link to documentation
echo -e "\033[1mDocumentation --------------------------------\033[0m"
echo "https://carmeteam.github.io/Carme-Docu/UserDoc"
echo ""

# print job information
echo -e "\033[1mJob Information ------------------------------\033[0m"
echo "Job-ID|-Name: ${CARME_JOB_ID:?"not set"} | ${CARME_JOB_NAME:?"not set"}"
echo "Nodes:        ${CARME_NODES:?"not set"}"
if [[ -n "$(echo "${CARME_JOB_GPUS:?"not set"}" | tr ',' '\n' | wc -l)" ]];then
  echo "GPUs/Node:    $(echo "${CARME_JOB_GPUS:?"not set"}" | tr ',' '\n' | wc -l)"
fi
if [[ -n "${CARME_JOB_GPUS:?"not set"}" ]];then
  echo "GPU-ID(s):    ${CARME_JOB_GPUS:?"not set"}"
fi
echo "End-Time:   $(grep "^${CARME_JOB_ID:?"not set"}[[:space:]]${CARME_JOB_NAME:?"not set"}" .local/share/carme/job-log-dir/job-log.dat | awk '{print $6}')"
