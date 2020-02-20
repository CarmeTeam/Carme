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
CARME_JOB_DIR="${HOME}/.local/share/carme/job/${SLURM_JOB_ID}"
[[ -f "${CARME_JOB_DIR}/bashrc" ]] && source "${CARME_JOB_DIR}/bashrc"


# add variables that should be availabe in ssh
[[ -f "${CARME_JOB_DIR}/ssh/envs/$(hostname)" ]] && source "${CARME_JOB_DIR}/ssh/envs/$(hostname)"

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


# make anaconda environment visible ------------------------------------------------------------------------------------------------
if [[ -f "/opt/anaconda3/etc/profile.d/conda.sh" ]];then
  source "/opt/anaconda3/etc/profile.d/conda.sh"
  conda activate base
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
