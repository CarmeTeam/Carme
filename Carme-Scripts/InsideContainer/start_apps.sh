#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# CARME:
# this script starts the applications inside the singularity container
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
  echo "$(currenttime) $(hostname): ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function for output -------------------------------------------------------------------------------------------------------
function log () {
  echo "$(currenttime) $(hostname): ${1}"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# write LD_LIBRARY_PATH to local hostname specific env file ------------------------------------------------------------------------
echo "export LD_LIBRARY_PATH=\"${LD_LIBRARY_PATH}\"
" >> "${CARME_SSHDIR}/envs/$(hostname)"
#-----------------------------------------------------------------------------------------------------------------------------------


# activate conda base environment --------------------------------------------------------------------------------------------------
# NOTE: conda should always be activated not only in interactive shells
CONDA_INIT_FILE="/opt/anaconda3/etc/profile.d/conda.sh"
if [[ -f "${CONDA_INIT_FILE}" ]];then
  log "activate conda base environment"
  source "${CONDA_INIT_FILE}"
  conda activate base
fi
#-----------------------------------------------------------------------------------------------------------------------------------


if [[ "$(hostname)" == "${CARME_MASTER}" ]];then

  # start ssh server if we have more than one node or more than one GPU ------------------------------------------------------------
  if [[ "${CARME_START_SSHD}" == "always" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1") ]];then
    log "start SSHD server"
    /usr/sbin/sshd -p "${SSHD_PORT}" -D -h "${CARME_SSHDIR}/server_key" -E "${CARME_SSHDIR}/sshd/$(hostname).log" -f "${CARME_SSHDIR}/sshd/$(hostname).conf" &
  fi
  #---------------------------------------------------------------------------------------------------------------------------------


  # start tensorboard --------------------------------------------------------------------------------------------------------------
  log "start TensorBoard at ${CARME_MASTER_IP}:${TB_PORT}"
  LC_ALL=C tensorboard --logdir="${CARME_TBDIR}" --port="${TB_PORT}" --path_prefix="/tb_${CARME_HASH}" & 
  #---------------------------------------------------------------------------------------------------------------------------------


  # start theia --------------------------------------------------------------------------------------------------------------------
  THEIA_BASE_DIR="/opt/theia-ide/"
  if [[ -d "${THEIA_BASE_DIR}" ]]; then
    cd "${THEIA_BASE_DIR}" || die "ERROR: $(hostname): cannot open ${THEIA_BASE_DIR}"
    log "start Theia at ${CARME_MASTER_IP}:${TA_PORT}"
    node node_modules/.bin/theia start "${HOME}" --hostname "${CARME_MASTER_IP}" --port "${TA_PORT}" --startup-timeout -1 --plugins=local-dir:plugins &
    cd || die "cannot change directory"
  fi
  #---------------------------------------------------------------------------------------------------------------------------------


  # start jupyter-lab --------------------------------------------------------------------------------------------------------------
  log "start JupyterLab at ${CARME_MASTER_IP}:${NB_PORT}"
  jupyter lab --ip="${CARME_MASTER_IP}" --port="${NB_PORT}" --notebook-dir=/home --no-browser --NotebookApp.base_url="/nb_${CARME_HASH}" --LabApp.workspaces_dir="${CARME_JUPYTERLAB_WORKSPACESDIR}" --LabApp.quit_button=False --LabApp.disable_check_xsrf=True --LabApp.token='' &
  #---------------------------------------------------------------------------------------------------------------------------------

else

  # start ssh server if a job has more than one node or mor than one GPU -----------------------------------------------------------
  if [[ "${CARME_START_SSHD}" == "always" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1") ]];then
    log "start SSHD server"
    /usr/sbin/sshd -p "${SSHD_PORT}" -D -h "${CARME_SSHDIR}/server_key" -E "${CARME_SSHDIR}/sshd/$(hostname).log" -f "${CARME_SSHDIR}/sshd/$(hostname).conf" &
  fi
  #---------------------------------------------------------------------------------------------------------------------------------

fi


# wait until the job is done -------------------------------------------------------------------------------------------------------
wait
#-----------------------------------------------------------------------------------------------------------------------------------
