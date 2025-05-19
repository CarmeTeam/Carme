#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# CARME: Script to start the default applications inside the singularity container
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to print time and date -------------------------------------------------------------------------------------------
function currenttime () {
  date +"[%F %T.%3N]"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "$(currenttime) $(hostname -s): ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function for output -------------------------------------------------------------------------------------------------------
function log () {
  echo "$(currenttime) $(hostname -s): ${1}"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to check if command is available on PATH -------------------------------------------------------------------------
function command_exists () {
  command -v "${1}" >/dev/null 2>&1
}
#-----------------------------------------------------------------------------------------------------------------------------------


# write LD_LIBRARY_PATH to local hostname specific env file ------------------------------------------------------------------------
echo "export LD_LIBRARY_PATH=\"${LD_LIBRARY_PATH}\"
" >> "${CARME_SSHDIR}/envs/$(hostname -s)"
#-----------------------------------------------------------------------------------------------------------------------------------


# activate conda base environment --------------------------------------------------------------------------------------------------
# NOTE: conda should always be activated not only in interactive shells
CONDA_INIT_FILE="/opt/package-manager/etc/profile.d/conda.sh"
MAMBA_INIT_FILE="/opt/package-manager/etc/profile.d/mamba.sh"

[[ -f "${CONDA_INIT_FILE}" ]] && source "${CONDA_INIT_FILE}"
[[ -f "${MAMBA_INIT_FILE}" ]] && source "${MAMBA_INIT_FILE}"

if command -v "mamba" >/dev/null 2>&1 ;then
  mamba activate base
elif command -v "conda" >/dev/null 2>&1 ;then
  conda activate base
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# start the default applications ---------------------------------------------------------------------------------------------------
if [[ "$(hostname -s)" == "${CARME_MASTER}" ]];then

  # start SSHD server --------------------------------------------------------------------------------------------------------------
  if [[ "${CARME_START_SSHD}" == "yes" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1") ]];then
    if command_exists sshd;then
      log "start SSHD server at port ${SSHD_PORT}"
      /usr/sbin/sshd -p "${SSHD_PORT}" -D -h "${CARME_SSHDIR}/server_key" -E "${CARME_SSHDIR}/sshd/$(hostname -s).log" -f "${CARME_SSHDIR}/sshd/$(hostname -s).conf" &
    else
      die "cannot start SSHD (no executable found)"
    fi
  fi
  #---------------------------------------------------------------------------------------------------------------------------------


  # start TensorBoard --------------------------------------------------------------------------------------------------------------
  if command_exists tensorboard;then
    log "start TensorBoard at ${CARME_MASTER_IP}:${TB_PORT}"
    LC_ALL=C tensorboard --logdir="${CARME_TBDIR}" --port="${TB_PORT}" --path_prefix="/tb_${CARME_HASH}" & 
  fi
  #---------------------------------------------------------------------------------------------------------------------------------


  # start code-server --------------------------------------------------------------------------------------------------------------
  if [[ ! -d "${THEIA_BASE_DIR}" ]]; then
    if command_exists code-server;then
      log "start Code-Server at ${CARME_MASTER_IP}:${TA_PORT}"
      code-server --auth none --disable-telemetry --bind-addr ${CARME_MASTER_IP}:${TA_PORT} --app-name CARME-IDE --user-data-dir "${HOME}/.local/share/code-server" --extensions-dir "${HOME}/.local/share/code-server/extensions" &
    else
      die "cannot start Code-Server (no executable found)"
    fi
  fi
  #---------------------------------------------------------------------------------------------------------------------------------


  # start JupyterLab ---------------------------------------------------------------------------------------------------------------
  if command_exists jupyter; then
    log "start JupyterLab at ${CARME_MASTER_IP}:${NB_PORT}"
    jupyter lab --ip="${CARME_MASTER_IP}" --port="${NB_PORT}" --notebook-dir=/home --preferred-dir="${HOME}" --no-browser --NotebookApp.base_url="/nb_${CARME_HASH}" --LabApp.workspaces_dir="${CARME_JUPYTERLAB_WORKSPACESDIR}" --LabApp.quit_button=False --LabApp.disable_check_xsrf=True --LabApp.token='' --LabApp.log_datefmt="%Y-%m-%d %H:%M:%S" &
  else
    die "cannot start JupyterLab (no executable found)"
  fi
  #---------------------------------------------------------------------------------------------------------------------------------

else

  # start SSHD ---------------------------------------------------------------------------------------------------------------------
  if [[ "${CARME_START_SSHD}" == "yes" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1") ]];then
    if command_exists sshd;then
      log "start SSHD server at port ${SSHD_PORT}"
      /usr/sbin/sshd -p "${SSHD_PORT}" -D -h "${CARME_SSHDIR}/server_key" -E "${CARME_SSHDIR}/sshd/$(hostname -s).log" -f "${CARME_SSHDIR}/sshd/$(hostname -s).conf" &
    else
      die "cannot start SSHD (no executable found)"
    fi
  fi
  #---------------------------------------------------------------------------------------------------------------------------------

fi
#-----------------------------------------------------------------------------------------------------------------------------------


# wait until the job is done -------------------------------------------------------------------------------------------------------
wait
#-----------------------------------------------------------------------------------------------------------------------------------
