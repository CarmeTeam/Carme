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
echo "Job-ID|-Name: ${SLURM_JOB_ID} | ${SLURM_JOB_NAME}"
echo "Nodes:        ${CARME_NODES}"
if [[ -n "$(echo "${SLURM_JOB_GPUS}" | tr ',' '\n' | wc -l)" ]];then
  echo "GPUs/Node:    $(echo "${SLURM_JOB_GPUS}" | tr ',' '\n' | wc -l)"
fi
if [[ -n "${SLURM_JOB_GPUS}" ]];then
  echo "GPU-ID(s):    ${SLURM_JOB_GPUS}"
fi
echo "End-Time:   $(grep "^${SLURM_JOB_ID}[[:space:]]${SLURM_JOB_NAME}" .local/share/carme/job-log-dir/job-log.dat | awk '{print $6}')"
