#
# ${HOME}/.bashrc
#

# If not running interactively, don't do anything ----------------------------------------------------------------------------------
[[ $- != *i* ]] && return
#-----------------------------------------------------------------------------------------------------------------------------------


# redefine prompt and its color (can be overwritten in .bash_aliases) --------------------------------------------------------------
if [[ $- = *i* ]];then
  export PS1='[\[\033[01;35m\]\u\[\033[m\]@\[\033[01;32m\]\h\[\033[m\]:\[\033[01;31;1m\]\W\[\033[m\]]\$ '
else
  export PS1='[\u@\h:\W]\$ '
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# bash history settings ------------------------------------------------------------------------------------------------------------
# don't add duplicate lines or lines starting with space
HISTCONTROL=ignoreboth

# append to history
shopt -s histappend

# set history length
HISTSIZE=1000
HISTFILESIZE=2000
#-----------------------------------------------------------------------------------------------------------------------------------


# add bash completion --------------------------------------------------------------------------------------------------------------
if [ -f /usr/share/bash-completion/bash_completion ]; then
  . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi
# ----------------------------------------------------------------------------------------------------------------------------------


# add user specific bash settings --------------------------------------------------------------------------------------------------
[[ -f ${HOME}/.bash_aliases ]] && . ${HOME}/.bash_aliases
#-----------------------------------------------------------------------------------------------------------------------------------


# CARME specific changes -----------------------------------------------------------------------------------------------------------
# add specific bash functions
[[ -f /home/.CarmeScripts/carme_bash_functions.sh ]] && . /home/.CarmeScripts/carme_bash_functions.sh

# add job specific bash settings
if [[ -f ${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/bash_${SLURM_JOB_ID} ]];then
  . ${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/bash_${SLURM_JOB_ID}
fi

# add terminal welcome message
[[ -f /home/.CarmeScripts/carme-messages.sh ]] && . /home/.CarmeScripts/carme-messages.sh
#-----------------------------------------------------------------------------------------------------------------------------------


# make anaconda environment visible ------------------------------------------------------------------------------------------------
if [[ -f "/opt/anaconda3/etc/profile.d/conda.sh" ]];then
  source "/opt/anaconda3/etc/profile.d/conda.sh"
  conda activate base
fi
#-----------------------------------------------------------------------------------------------------------------------------------

