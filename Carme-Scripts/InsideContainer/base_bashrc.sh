#!/bin/bash
#
# /etc/bash.bashrc
#


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


  # add user specific bash settings ------------------------------------------------------------------------------------------------
  [[ -f "${HOME}/.bash_aliases" ]] && source "${HOME}/.bash_aliases"
  #---------------------------------------------------------------------------------------------------------------------------------


  # CARME specific changes ---------------------------------------------------------------------------------------------------------
  CARME_SCRIPTS_DIR="/home/.CarmeScripts"

  # add specific bash functions
  CARME_BASH_FUNCTIONS="${CARME_SCRIPTS_DIR}/carme_bash_functions.sh"
  [[ -f "${CARME_BASH_FUNCTIONS}" ]] && source "${CARME_BASH_FUNCTIONS}"

  # add job specific bash settings
  CARME_JOB_BASH="${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/bash_${SLURM_JOB_ID}"
  [[ -f "${CARME_JOB_BASH}" ]] && source "${CARME_JOB_BASH}"

  # add terminal welcome message
  CARME_MESSAGES="${CARME_SCRIPTS_DIR}/carme-messages.sh"
  [[ -f "${CARME_MESSAGES}" ]] && source "${CARME_MESSAGES}"
  #---------------------------------------------------------------------------------------------------------------------------------
else
  export PS1="[\u@\h:\W]\$ "
fi


# activate conda base environment --------------------------------------------------------------------------------------------------
# NOTE: conda should always be activated not only in interactive shells
CONDA_INIT_FILE="/opt/anaconda3/etc/profile.d/conda.sh"
if [[ -f "${CONDA_INIT_FILE}" ]];then
  source "${CONDA_INIT_FILE}"
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
