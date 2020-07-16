#!/bin/bash
#
# /etc/bash.bashrc
#


# CARME specific changes -----------------------------------------------------------------------------------------------------------
set -e
set -o pipefail

CARME_SCRIPTS_DIR="/home/.CarmeScripts"


# add specific bash functions
CARME_BASH_FUNCTIONS="${CARME_SCRIPTS_DIR}/carme_bash_functions.sh"
[[ -f "${CARME_BASH_FUNCTIONS}" ]] && source "${CARME_BASH_FUNCTIONS}"


# add job specific bash settings
[[ -n ${SLURM_JOB_ID} ]] && CARME_JOBDIR="${HOME}/.local/share/carme/job/${SLURM_JOB_ID}"
[[ -f "${CARME_JOBDIR}/bashrc" ]] && source "${CARME_JOBDIR}/bashrc"


# add variables that should be availabe in ssh
[[ -f "${CARME_JOBDIR}/ssh/envs/$(hostname)" ]] && source "${CARME_JOBDIR}/ssh/envs/$(hostname)"

set +e
set +o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


if [[ "$-" = *i* ]];then
  # redefine prompt and its color (can be overwritten in .bash_aliases) ------------------------------------------------------------
  export PS1="[\[\033[01;35m\]\u\[\033[m\]@\[\033[01;32m\]\h\[\033[m\]:\[\033[01;31;1m\]\W\[\033[m\]]\$ "
  #---------------------------------------------------------------------------------------------------------------------------------


  # bash history settings ----------------------------------------------------------------------------------------------------------
  # don't add duplicate lines or lines starting with space
  HISTCONTROL=ignoreboth


  # append to history
  shopt -s histappend


  # set history length
  HISTSIZE=1000
  HISTFILESIZE=2000
  #---------------------------------------------------------------------------------------------------------------------------------


  # add bash completion ------------------------------------------------------------------------------------------------------------
  if [ -f "/usr/share/bash-completion/bash_completion" ]; then
    source "/usr/share/bash-completion/bash_completion"
  elif [ -f "/etc/bash_completion" ]; then
    source "/etc/bash_completion"
  fi
  # --------------------------------------------------------------------------------------------------------------------------------


  # add terminal welcome message
  set -e
  set -o pipefail
  CARME_MESSAGES="${CARME_SCRIPTS_DIR}/carme-messages.sh"
  [[ -f "${CARME_MESSAGES}" && -z "${SSH_CLIENT}" ]] && source "${CARME_MESSAGES}"
  set +e
  set +o pipefail
  #---------------------------------------------------------------------------------------------------------------------------------
else
  export PS1="[\u@\h:\W]\$ "
fi


# redefine mpirun ------------------------------------------------------------------------------------------------------------------
if [[ -f "/usr/bin/mpirun" ]];then
  function carme_mpirun () {
    if [[ $# -eq 0 ]] ; then
      /usr/bin/mpirun
    elif [[ "${1}" == "--help" ]];then
      /usr/bin/mpirun --help
    elif [[ "${1}" == "-h" ]];then
      /usr/bin/mpirun -h
    elif [[ "${1}" == "--version" ]];then
      /usr/bin/mpirun --version
    elif [[ "${1}" == "-V" ]];then
      /usr/bin/mpirun -V
    else
      /usr/bin/mpirun --mca plm rsh --mca plm_rsh_args "-F ${HOME}/.local/share/carme/job/${CARME_JOB_ID:?"not set"}/ssh/ssh_config" --mca btl_openib_warn_default_gid_prefix 0 --wdir "${TMP}" --mca orte_tmpdir_base "${TMP}" --use-hwthread-cpus "${@}"
    fi
  }
  complete -f -d -c carme_mpirun
  export -f carme_mpirun
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# activate conda base environment --------------------------------------------------------------------------------------------------
# NOTE: conda should always be activated not only in interactive shells
CONDA_INIT_FILE="/opt/anaconda3/etc/profile.d/conda.sh"
if [[ -f "${CONDA_INIT_FILE}" ]];then
  source "${CONDA_INIT_FILE}"
  conda activate base
fi
#-----------------------------------------------------------------------------------------------------------------------------------
