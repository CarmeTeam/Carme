#!/bin/bash
#-----------------------------------------------------------------------------------------#
#---------------------------------- SCRIPTS installation ---------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# unset proxy -----------------------------------------------------------------------------
if [[ $http_proxy != "" || $https_proxy != "" ]]; then
    http_proxy=""
    https_proxy=""
fi

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then

  CARME_USER=$(get_variable CARME_USER ${FILE_START_CONFIG})
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})

else
  die "[install_scripts.sh]: ${FILE_START_CONFIG} not found."
fi

[[ -z ${CARME_USER} ]] && die "[install_scripts.sh]: CARME_USER not set."
[[ -z ${CARME_SYSTEM} ]] && die "[install_scripts.sh]: CARME_SYSTEM not set."
[[ -z ${CARME_NODE_LIST} ]] && die "[install_scripts.sh]: CARME_NODE_LIST not set."

# install variables ----------------------------------------------------------------------
PATH_SLURM=$(dpkg -L slurmctld | grep '/etc/slurm' | head -n1)
PATH_SLURMCTLD_LOG="/var/log/carme/slurmctld"
PATH_SCRIPTS_BACKEND="${PATH_CARME}/Carme-Scripts/backend"
PATH_SCRIPTS_FRONTEND="${PATH_CARME}/Carme-Scripts/frontend"
PATH_SCRIPTS_CONTAINER="${PATH_CARME}/Carme-Scripts/InsideContainer"
PATH_SCRIPTS_SLURM_JOB="${PATH_CARME}/Carme-Scripts/slurm/job-scripts"

FILE_SLURM_CONFIG=${PATH_SLURM}/slurm.conf
FILE_SLURMCTLD_PROLOG="${PATH_SCRIPTS_SLURM_JOB}/slurmctld-prolog-scripts/prolog.sh"
FILE_SLURMCTLD_EPILOG="${PATH_SCRIPTS_SLURM_JOB}/slurmctld-epilog-scripts/epilog.sh"
FILE_SLURMD_PROLOG="${PATH_SCRIPTS_SLURM_JOB}/slurm-prolog-scripts/carme-node-prolog.sh"
FILE_SLURMD_EPILOG="${PATH_SCRIPTS_SLURM_JOB}/slurm-epilog-scripts/carme-node-epilog.sh"

[[ ! -f ${FILE_SLURMD_PROLOG} ]] && die "[install_scripts.sh]: ${FILE_SLURMD_PROLOG} not found."
[[ ! -f ${FILE_SLURMD_EPILOG} ]] && die "[install_scripts.sh]: ${FILE_SLURMD_EPILOG} not found."
[[ ! -f ${FILE_SLURMCTLD_PROLOG} ]] && die "[install_scripts.sh]: ${FILE_SLURMCTLD_PROLOG} not found."
[[ ! -f ${FILE_SLURMCTLD_EPILOG} ]] && die "[install_scripts.sh]: ${FILE_SLURMCTLD_EPILOG} not found."

# installation starts ---------------------------------------------------------------------
log "starting scripts installation..."

# change permissions ----------------------------------------------------------------------
log "create executable files..."

chmod 755 -R ${PATH_SCRIPTS_BACKEND}
chmod 755 -R ${PATH_SCRIPTS_FRONTEND}
chmod 755 -R ${PATH_SCRIPTS_CONTAINER}
chmod 755 -R ${PATH_SCRIPTS_SLURM_JOB}

# check services --------------------------------------------------------------------------
log "checking services (please wait)..."

systemctl is-active --quiet slurmctld || die "[install_scripts.sh]: slurmctld.service is not running. Please contact us."
if [[ ${CARME_SYSTEM} == "single" ]]; then
  systemctl is-active --quiet slurmd || die "[install_scripts.sh]: slurmd.service is not running. Please contact us."
else
  for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
    SLURMD_STATUS=$(ssh ${COMPUTE_NODE} 'systemctl is-active --quiet slurmd && echo "running" || echo "not running"')
    if [[ $SLURMD_STATUS == "not running" ]]; then
      die "[install_scripts.sh]: slurmd service in compute-node ${COMPUTE_NODE} is not running. Please contact us."
    fi
  done
fi

# set path to scripts in slurm.conf -------------------------------------------------------
if grep -q -F "#Prolog=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:#Prolog=.*:Prolog=${FILE_SLURMD_PROLOG}:" ${PATH_SLURM}/slurm.conf
elif grep -q -F "Prolog=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:Prolog=.*:Prolog=${FILE_SLURMD_PROLOG}:" ${PATH_SLURM}/slurm.conf	
else
  die "[install_scripts.sh]: Prolog does not exist in ${PATH_SLURM}/slurm.conf. Please contact us."
fi

if grep -q -F "#Epilog=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:#Epilog=.*:Epilog=${FILE_SLURMD_EPILOG}:" ${PATH_SLURM}/slurm.conf
elif grep -q -F "Epilog=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:Epilog=.*:Epilog=${FILE_SLURMD_EPILOG}:" ${PATH_SLURM}/slurm.conf
else
  die "[install_scripts.sh]: Epilog does not exist in ${PATH_SLURM}/slurm.conf. Please contact us."
fi

if grep -q -F "#PrologSlurmctld=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:#PrologSlurmctld=.*:PrologSlurmctld=${FILE_SLURMCTLD_PROLOG}:" ${PATH_SLURM}/slurm.conf
elif grep -q -F "PrologSlurmctld=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:PrologSlurmctld=.*:PrologSlurmctld=${FILE_SLURMCTLD_PROLOG}:" ${PATH_SLURM}/slurm.conf
else
  die "[install_scripts.sh]: PrologSlurmctld does not exist in ${PATH_SLURM}/slurm.conf. Please contact us."
fi

if grep -q -F "#EpilogSlurmctld=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:#EpilogSlurmctld=.*:EpilogSlurmctld=${FILE_SLURMCTLD_EPILOG}:" ${PATH_SLURM}/slurm.conf
elif grep -q -F "EpilogSlurmctld=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:EpilogSlurmctld=.*:EpilogSlurmctld=${FILE_SLURMCTLD_EPILOG}:" ${PATH_SLURM}/slurm.conf
else
  die "[install_scripts.sh]: EpilogSlurmctld does not exist in ${PATH_SLURM}/slurm.conf. Please contact us."
fi

# create log directories ------------------------------------------------------------------
mkdir -p ${PATH_SLURMCTLD_LOG}/prolog/
mkdir -p ${PATH_SLURMCTLD_LOG}/epilog/

# set ownership ---------------------------------------------------------------------------
chown -R slurm:slurm ${PATH_SLURMCTLD_LOG}

# restart slurm ---------------------------------------------------------------------------
if [[ ${CARME_SYSTEM} == "single" ]]; then
  systemctl restart slurmctld
  systemctl restart slurmdbd
  systemctl restart slurmd
  scontrol reconfig

  sleep 10
  scontrol update nodename=$(hostname -s) state=idle
  node_state=$(scontrol show node=$(hostname -s) State | grep State | awk '{print $1;}')
  if [[ $node_state != "State=IDLE" ]];then
    die "[install_scripts.sh]: node state is not idle."
  fi
else
  # copy slurm.conf to all compute nodes ----------------------------------------------------
  log "copying files to compute-nodes..."
  for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
    scp -q ${FILE_SLURM_CONFIG} ${COMPUTE_NODE}:${FILE_SLURM_CONFIG} && log "slurm.conf copied to ${COMPUTE_NODE}"
  done

  # restart slurm services ------------------------------------------------------------------
  systemctl restart slurmctld
  systemctl restart slurmdbd

  systemctl is-active --quiet slurmctld || die "[install_scripts.sh]: slurmctld.service in head-node is not running."
  systemctl is-active --quiet slurmdbd || die "[install_scripts.sh]: slurmdbd.service in head-node is not running."

  for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
    ssh ${COMPUTE_NODE} 'systemctl restart slurmd'
    SLURMD_STATUS=$(ssh ${COMPUTE_NODE} 'systemctl is-active --quiet slurmd && echo "running" || echo "not running"')
    if [[ $SLURMD_STATUS == "not running" ]]; then
      die "[install_scripts.sh]: slurmd service in compute-node ${COMPUTE_NODE} is not running."
    fi
  done

  scontrol reconfig
fi
log "carme-scripts successfully installed."
