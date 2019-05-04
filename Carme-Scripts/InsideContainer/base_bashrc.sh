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

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

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
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

#if [ -f ~/.bash_aliases ]; then
#    . ~/.bash_aliases
#fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi


function carme_canceljob() {
    NUMBERCHECK='^[0-9]+$'
    if ! [[ $1 =~ $NUMBERCHECK ]];then
        VALUE=( $(ps ax | grep "$1" | grep -v grep | awk '{ print $1 }') )
        echo "${VALUE[0]}"
        kill ${VALUE[0]}
        VALUE=( $(ps ax | grep "$1" | grep -v grep | awk '{ print $1 }') )
        if [[ ! -z ${VALUE[0]} ]];then
            pgrep -P ${VALUE[0]} | xargs kill -9
            kill -9 ${VALUE[0]}
        fi
								sleep 1
        VALUE=( $(ps ax | grep "$1" | grep -v grep | awk '{ print $1 }') )
        if [[ ! -z ${VALUE[0]} ]];then
            echo "your job cannot be killed, please contact your systemadministrator"
        fi
    else
        pgrep -P $1 | xargs kill
        kill $1
        VALUE=( $(ps ax | grep $1 | grep -v grep | awk '{ print $1 }') )
        if [[ ! -z ${VALUE[0]} ]];then
            pgrep -P $1 | xargs kill -9
            kill -9 $1
        fi
								sleep 1
        VALUE=( $(ps ax | grep "$1" | grep -v grep | awk '{ print $1 }') )
        if [[ ! -z ${VALUE[0]} ]];then
            echo "your job cannot be killed, please contact your systemadministrator"
        fi
    fi
}

export LANG=en_US.utf8

#export TMOUT=1800

# redefine prompt and its color (can be overwritten in .bash_aliases)
if [[ $- = *i* ]];then
  export PS1='[\[\033[01;35m\]\u\[\033[m\]@\[\033[01;32m\]\h\[\033[m\]:\[\033[01;31;1m\]\W\[\033[m\]]\$ '
fi


#include job settings
chmod 700 ~/.carme/.bash_carme_$SLURM_JOBID
[[ -f ~/.carme/.bash_carme_$SLURM_JOBID ]] && . ~/.carme/.bash_carme_$SLURM_JOBID

#terminal welcome message
[[ -f /home/.CarmeScripts/carme-messages.sh ]] && . /home/.CarmeScripts/carme-messages.sh

#include user settings
chmod 700 ~/.bash_aliases 
[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases

#alias for watch that it works with predefined aliases (trailing space inside the quotation marks needed!!!)
alias watch='watch '

#alias for python linking to the anaconda installation
alias python='/opt/anaconda3/bin/python'
export PATH=$PATH:/opt/anaconda3/bin/:/home/.CarmeScripts/bash/:/opt/cuda-9.0/bin/ 

# compress and extract functions
function carme-archive (){
  parameter_array=($@)
  parameter_array_length=${#parameter_array[@]}
  if [[ "$parameter_array_length" -le "1" ]];then
    if [ "${parameter_array[0]}" == "--help"  ] || [ "${parameter_array[0]}" == "-h" ]; then
      echo "carme-archive creates a compressed tar-file (tar.gz) of"
      echo "the specified folder(s)/file(s) (see USAGE) and after the"
      echo "archive is created deletes the original folder(s)/file(s)."
      echo ""
      echo "USAGE:"
      echo "carme-archive ARCHIVE-NAME FOLDER"
      echo "or"
      echo "carme-archive ARCHIVE-NAME FOLDER-1 FOLDER-2 ..."
      echo "or"
      echo "carme-archive ARCHIVE-NAME FILE-1 FILE-2 FILE3 ..."
    else
      echo "You did not specify an archive name or a folder/files to archive!"
      echo "Use carme-archive --help or carme-archive -h for more information."
    fi
  else
    archive_name="${parameter_array[@]:0:1}"
    archive_files=("${parameter_array[@]:1:$parameter_array_length}")
    
    tar -vczf $archive_name.tar.gz ${archive_files[@]} --remove-files
  fi
}
complete -f -d carme-archive


function carme-unarchive (){
  archive_name=$1
  if [[ -z $archive_name ]];then
      echo "You did not specify an archive to extract!"
      echo "Use carme-unarchive --help or carme-unarchive -h for more information."
  elif [ "$archive_name" == "--help"  ] || [ "$archive_name" == "-h" ]; then
      echo "carme-unarchive extracts a compressed tar-file (tar.gz)"
      echo "in the local folder and then removes the original archive."
      echo ""
      echo "USAGE:"
      echo "carme-unarchive ARCHIVE-NAME.tar.gz"
  else
  
    tar -vxzf $archive_name
    
    if [ $? != 0 ];then
      echo "extracting $1 failed"
    else
      rm -v $1
    fi
  fi
}
complete -f carme-unarchive


# add and remove results to tensorboard
function carme_tensorboard_visualize () {
  parameter_array=($@)
  parameter_array_length=${#parameter_array[@]}
  if [[ "$parameter_array_length" -gt "1" ]];then
    echo "You can only link one folder, use --help or -h for more information"
  elif [[ "$parameter_array_length" -le "1" ]];then
    if [ "${parameter_array[0]}" == "--help"  ] || [ "${parameter_array[0]}" == "-h" ]; then
      echo "With carme_tensorboard_visualize you can add previous results to your running tensorboard."
      echo "You should only add the results you need (and not your entire home folder)!! Per default a"
      echo "job starts with an empty tensorboard folder in HOME/tensorboard/tensorboad_JOBID and only"
      echo "this folder is visualized in the running job. Note that this folder is delated on a regular"
      echo "base. Therefore you should use this function to temporarily make your results visible in"
      echo "your running job."
      echo ""
      echo "USAGE:"
      echo "e.g. carme_tensorboard_visualize results/my-results-1"
      echo ""
      echo "NOTE:"
      echo "You can delete such a temporarily visible folder with carme_tensorboard_unvisualize."
    else
      dir_name=${parameter_array[0]}
      full_dir_name=$(realpath $dir_name)
      link_name=$(realpath ${dir_name} | sed 's/.*\///')
      ln -s ${full_dir_name} ${HOME}/tensorboard/tensorboard_${SLURM_JOB_ID}/${link_name}
      echo "added ${link_name} to tensorboard"
    fi
  fi
}
complete -d carme_tensorboard_visualize


function carme_tensorboard_unvisualize () {
  parameter_array=($@)
  parameter_array_length=${#parameter_array[@]}
  if [[ "$parameter_array_length" -gt "1" ]];then
    echo "You can only remove one link, use --help or -h for more information"
  elif [[ "$parameter_array_length" -le "1" ]];then
    if [ "${parameter_array[0]}" == "--help"  ] || [ "${parameter_array[0]}" == "-h" ]; then
      echo "With carme_tensorboard_unvisualize you can remove results so that they are no longer"
      echo "visible within tensorboard in your runinng job."
      echo ""
      echo "USAGE:"
      echo "e.g. carme_tensorboard_unvisualize tensorboard/tensorboard_JOBID/my-results"
    else
      dir_name=${parameter_array[0]}
      full_dir_name=$(realpath $dir_name)
      link_name=$(realpath ${dir_name} | sed 's/.*\///')
      rm ${HOME}/tensorboard/tensorboard_${SLURM_JOB_ID}/${link_name}
      echo "removed ${link_name} from tensorboard"
    fi
  fi
}
complete -f -d carme_tensorboard_unvisualize


function carme_tensorboard_ls () {
  if [ "$1" == "--help"  ] || [ "$1" == "-h" ];then
    echo "With carme_tensorboard_ls you can see which folders"
    echo "are linked to your current tensorboard job-folder."
    echo ""
    echo "USAGE:"
    echo "carme_tensorboard_ls"
  elif [ -z "$1" ];then
    ls -lah ${HOME}/tensorboard/tensorboard_${SLURM_JOB_ID}
  else
    echo "Use --help or -h to get more information."
  fi
}

