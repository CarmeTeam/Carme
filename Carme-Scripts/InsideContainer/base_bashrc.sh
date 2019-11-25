# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -lahv'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'


#-----------------------------------------------------------------------------------------------------------------------------------
# alias definitions ----------------------------------------------------------------------------------------------------------------
# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).

# add bash completion --------------------------------------------------------------------------------------------------------------
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
# ----------------------------------------------------------------------------------------------------------------------------------


# add user specific bash settings --------------------------------------------------------------------------------------------------
[[ -f ${HOME}/.bash_aliases ]] && . ${HOME}/.bash_aliases
#-----------------------------------------------------------------------------------------------------------------------------------


# add carme specific bash functions ------------------------------------------------------------------------------------------------
[[ -f /home/.CarmeScripts/carme_bash_functions.sh ]] && . /home/.CarmeScripts/carme_bash_functions.sh
#-----------------------------------------------------------------------------------------------------------------------------------


# set LANG to english --------------------------------------------------------------------------------------------------------------
export LANG=en_US.utf8
#-----------------------------------------------------------------------------------------------------------------------------------


# redefine prompt and its color (can be overwritten in .bash_aliases) --------------------------------------------------------------
if [[ $- = *i* ]];then
  export PS1='[\[\033[01;35m\]\u\[\033[m\]@\[\033[01;32m\]\h\[\033[m\]:\[\033[01;31;1m\]\W\[\033[m\]]\$ '
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# include job specific bash settings ------------------------------------------------------------------------------------------------
if [[ -f ${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/bash_${SLURM_JOB_ID} ]];then
  . ${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/bash_${SLURM_JOB_ID}
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# add terminal welcome message -----------------------------------------------------------------------------------------------------
[[ -f /home/.CarmeScripts/carme-messages.sh ]] && . /home/.CarmeScripts/carme-messages.sh
#-----------------------------------------------------------------------------------------------------------------------------------


# modify $PATH ---------------------------------------------------------------------------------------------------------------------
export PATH=$PATH:/opt/anaconda3/bin/:/home/.CarmeScripts/bash/:/opt/cuda/cuda_9/bin/
#-----------------------------------------------------------------------------------------------------------------------------------


# make anaconda environment visible for users --------------------------------------------------------------------------------------
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
#-----------------------------------------------------------------------------------------------------------------------------------

