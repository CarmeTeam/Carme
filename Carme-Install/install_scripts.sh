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
  CARME_SLURM=$(get_variable CARME_SLURM ${FILE_START_CONFIG})
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})

else
  die "[install_scripts.sh]: ${FILE_START_CONFIG} not found."
fi

[[ -z ${CARME_USER} ]] && die "[install_scripts.sh]: CARME_USER not set."
[[ -z ${CARME_SYSTEM} ]] && die "[install_scripts.sh]: CARME_SYSTEM not set."
[[ -z ${CARME_NODE_LIST} ]] && die "[install_scripts.sh]: CARME_NODE_LIST not set."

# install variables ----------------------------------------------------------------------
SLURM_PATHS_PACKAGE=slurmctld
if [[ $SYSTEM_DIST == "rocky" ]]; then
  SLURM_PATHS_PACKAGE=slurm
fi

PATH_SLURM=$(list_packages_files ${SLURM_PATHS_PACKAGE} | grep '/etc/slurm' | head -n1)
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
if grep -q "^Prolog=.*\*" "${PATH_SLURM}/slurm.conf"; then
  OLD_DIR="$(grep "^Prolog=" "${PATH_SLURM}/slurm.conf" | cut -d= -f2)"
  cp "${FILE_SLURMD_PROLOG}" "${PATH_SLURM}/prolog.d"
elif grep -q "^Prolog=" "${PATH_SLURM}/slurm.conf"; then
  OLD_SCRIPT="$(grep "^Prolog=" "${PATH_SLURM}/slurm.conf" | cut -d= -f2)"
  mkdir -p "${PATH_SLURM}/prolog.d"
  cp "${OLD_SCRIPT}" "${PATH_SLURM}/prolog.d"
  cp "${FILE_SLURMD_PROLOG}" "${PATH_SLURM}/prolog.d"
  sed -i "s:Prolog=.*:Prolog=${PATH_SLURM}/prolog.d/*:" ${PATH_SLURM}/slurm.conf
elif grep -q -F "#Prolog=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:#Prolog=.*:Prolog=${FILE_SLURMD_PROLOG}:" ${PATH_SLURM}/slurm.conf
else
  die "[install_scripts.sh]: Prolog does not exist in ${PATH_SLURM}/slurm.conf. Please contact us."
fi

if grep -q "^Epilog=.*\*" "${PATH_SLURM}/slurm.conf"; then
  OLD_DIR="$(grep "^Epilog=" "${PATH_SLURM}/slurm.conf" | cut -d= -f2)"
  cp "${FILE_SLURMD_EPILOG}" "${PATH_SLURM}/epilog.d"
elif grep -q "^Epilog=" "${PATH_SLURM}/slurm.conf"; then
  OLD_SCRIPT="$(grep "^Epilog=" "${PATH_SLURM}/slurm.conf" | cut -d= -f2)"
  mkdir -p "${PATH_SLURM}/epilog.d"
  cp "${OLD_SCRIPT}" "${PATH_SLURM}/epilog.d"
  cp "${FILE_SLURMD_EPILOG}" "${PATH_SLURM}/epilog.d"
  sed -i "s:Epilog=.*:Epilog=${PATH_SLURM}/epilog.d/*:" ${PATH_SLURM}/slurm.conf
elif grep -q -F "#Epilog=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:#Epilog=.*:Epilog=${FILE_SLURMD_EPILOG}:" ${PATH_SLURM}/slurm.conf
else
  die "[install_scripts.sh]: Epilog does not exist in ${PATH_SLURM}/slurm.conf. Please contact us."
fi

if grep -q "^PrologSlurmctld=.*\*" "${PATH_SLURM}/slurm.conf"; then
  OLD_DIR="$(grep "^PrologSlurmctld=" "${PATH_SLURM}/slurm.conf" | cut -d= -f2)"
  cp "${FILE_SLURMCTLD_PROLOG}" "${PATH_SLURM}/prologslurmctld.d"
elif grep -q "^PrologSlurmctld=" "${PATH_SLURM}/slurm.conf"; then
  OLD_SCRIPT="$(grep "^PrologSlurmctld=" "${PATH_SLURM}/slurm.conf" | cut -d= -f2)"
  mkdir -p "${PATH_SLURM}/prologslurmctld.d"
  cp "${OLD_SCRIPT}" "${PATH_SLURM}/prologslurmctld.d"
  cp "${FILE_SLURMCTLD_PROLOG}" "${PATH_SLURM}/prologslurmctld.d"
  sed -i "s:PrologSlurmctld=.*:PrologSlurmctld=${PATH_SLURM}/prologslurmctld.d/*:" ${PATH_SLURM}/slurm.conf
elif grep -q -F "#PrologSlurmctld=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:#PrologSlurmctld=.*:PrologSlurmctld=${FILE_SLURMCTLD_PROLOG}:" ${PATH_SLURM}/slurm.conf
else
  die "[install_scripts.sh]: PrologSlurmctld does not exist in ${PATH_SLURM}/slurm.conf. Please contact us."
fi

if grep -q "^EpilogSlurmctld=.*\*" "${PATH_SLURM}/slurm.conf"; then
  OLD_DIR="$(grep "^EpilogSlurmctld=" "${PATH_SLURM}/slurm.conf" | cut -d= -f2)"
  cp "${FILE_SLURMCTLD_EPILOG}" "${PATH_SLURM}/epilogslurmctld.d"
elif grep -q "^EpilogSlurmctld=" "${PATH_SLURM}/slurm.conf"; then
  OLD_SCRIPT="$(grep "^EpilogSlurmctld=" "${PATH_SLURM}/slurm.conf" | cut -d= -f2)"
  mkdir -p "${PATH_SLURM}/epilogslurmctld.d"
  cp "${OLD_SCRIPT}" "${PATH_SLURM}/epilogslurmctld.d"
  cp "${FILE_SLURMCTLD_EPILOG}" "${PATH_SLURM}/epilogslurmctld.d"
  sed -i "s:EpilogSlurmctld=.*:EpilogSlurmctld=${PATH_SLURM}/epilogslurmctld.d/*:" ${PATH_SLURM}/slurm.conf
elif grep -q -F "#EpilogSlurmctld=" "${PATH_SLURM}/slurm.conf"; then
  sed -i "s:#EpilogSlurmctld=.*:EpilogSlurmctld=${FILE_SLURMCTLD_EPILOG}:" ${PATH_SLURM}/slurm.conf
else
  die "[install_scripts.sh]: EpilogSlurmctld does not exist in ${PATH_SLURM}/slurm.conf. Please contact us."
fi

# remove duplicates (if exists) -----------------------------------------------------------
awk '!seen[$0]++' ${PATH_SLURM}/slurm.conf > ${PATH_SLURM}/slurm.conf.tmp
mv ${PATH_SLURM}/slurm.conf.tmp ${PATH_SLURM}/slurm.conf

# create log directories ------------------------------------------------------------------
mkdir -p ${PATH_SLURMCTLD_LOG}/prolog/
mkdir -p ${PATH_SLURMCTLD_LOG}/epilog/

# set ownership ---------------------------------------------------------------------------
if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
  chown -R slurm:slurm ${PATH_SLURMCTLD_LOG}
fi

# restart slurm ---------------------------------------------------------------------------
if [[ ${CARME_SYSTEM} == "single" ]]; then
  systemctl restart slurmctld
  systemctl restart slurmdbd
  systemctl restart slurmd
  scontrol reconfig

  sleep 10
  scontrol update nodename=$(hostname -s | awk '{print $1}') state=idle
  node_state=$(scontrol show node=$(hostname -s | awk '{print $1}') State | grep State | awk '{print $1;}')
  if [[ $node_state != "State=IDLE" ]];then
    die "[install_scripts.sh]: node state is not idle."
  fi
else

  # set compute node list
  if [[ ${CARME_SLURM} == "yes" ]]; then
    NODE_LIST=${CARME_NODE_LIST}
  elif [[ ${CARME_SLURM} == "no" ]]; then
    CLUSTER_NODE_LIST=$(sinfo -Nh --format="%N")
    # remove repetitive names in list
    declare -A uniq
    for k in ${CLUSTER_NODE_LIST} ; do uniq[$k]=1 ; done
    NODE_LIST=${!uniq[@]}
  fi
   
  # copy slurm.conf to all compute nodes ----------------------------------------------------
  log "copying files to compute-nodes..."

  for COMPUTE_NODE in ${NODE_LIST[@]}; do
    scp -q ${FILE_SLURM_CONFIG} ${COMPUTE_NODE}:${FILE_SLURM_CONFIG} && log "slurm.conf copied to ${COMPUTE_NODE}"
    [ -d "${PATH_SLURM}/prolog.d" ] && scp -rq "${PATH_SLURM}/prolog.d" ${COMPUTE_NODE}:${PATH_SLURM} && log "prolog.d copied to ${COMPUTE_NODE}"
    [ -d "${PATH_SLURM}/epilog.d" ] && scp -rq "${PATH_SLURM}/epilog.d" ${COMPUTE_NODE}:${PATH_SLURM} && log "epilog.d copied to ${COMPUTE_NODE}"
  done

  # restart slurm services ------------------------------------------------------------------
  systemctl restart slurmctld
  systemctl restart slurmdbd

  systemctl is-active --quiet slurmctld || die "[install_scripts.sh]: slurmctld.service in head-node is not running."
  systemctl is-active --quiet slurmdbd || die "[install_scripts.sh]: slurmdbd.service in head-node is not running."

  for COMPUTE_NODE in ${NODE_LIST[@]}; do
    ssh ${COMPUTE_NODE} 'systemctl restart slurmd'
    SLURMD_STATUS=$(ssh ${COMPUTE_NODE} 'systemctl is-active --quiet slurmd && echo "running" || echo "not running"')
    if [[ $SLURMD_STATUS == "not running" ]]; then
      die "[install_scripts.sh]: slurmd service in compute-node ${COMPUTE_NODE} is not running."
    fi
  done

  scontrol reconfig
fi
log "carme-scripts successfully installed."
