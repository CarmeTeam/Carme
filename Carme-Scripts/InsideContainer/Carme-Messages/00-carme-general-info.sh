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
echo "Job-ID:     ${CARME_JOBID}"
echo "Job-Name:   ${CARME_JOB_NAME}"
echo "Nodes:      ${CARME_NODES}"
echo "GPUs/Node:  ${CARME_GPUS_PER_NODE}"
#echo "CPUs/Node:  ${CARME_CPUS_PER_NODE}"
#echo "MEM/Node:   ${CARME_MEM_PER_NODE}MB"
echo "End-Time:   $(grep $CARME_JOBID .local/share/carme/job-log-dir/job-log.dat | awk '{print $6}')"
echo ""

# print base ennv information
echo -e "\033[1mBase Environment -----------------------------\033[0m"
echo "TensorFlow: $(grep "tensorflow-gpu" ${HOME}/conda_base.txt | awk '{ print $2 }')"
echo "PyTorch:    $(grep "pytorch" ${HOME}/conda_base.txt | awk '{ print $2 }')"
#echo "CUDA:       $(nvcc --version | grep release | awk '{print $6}')"
#echo "CUDNN:      $(cat /opt/cuda/include/cudnn.h | grep "define CUDNN_MAJOR" | awk '{print $3}' | cut -d/ -f1)"
echo ""

