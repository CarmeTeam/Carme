#!/bin/bash
#--------------------------------------------------------------------------------------------------#
#----------------------------------------- Basic Functions  ---------------------------------------#
#--------------------------------------------------------------------------------------------------#

# show version -------------------------------------------------------------------------------------
CARME_VERSION="v0.99"

# show time ----------------------------------------------------------------------------------------
function currenttime () {
  date +"[%F %T.%3N]"
}

# log message --------------------------------------------------------------------------------------
function log () {
  echo "$(currenttime) ${1}"
}

# error message ------------------------------------------------------------------------------------
function die () {
  echo "$(currenttime) ERROR ${1}"
  exit 200
}

# check command ------------------------------------------------------------------------------------
function check_command () {
  if ! command -v "${1}" >/dev/null 2>&1 ;then
    apt install -y ${1}
    if ! command -v "${1}" >/dev/null 2>&1 ;then
      die "command '${1}' not found"
    fi
  fi
}
check_command grep
check_command eval
check_command sed
check_command lsof

# check sudo ---------------------------------------------------------------------------------------
function check_sudo () {
  if [ "$EUID" -ne 0 ]; then
    die "Please run as root"
  fi
}
check_sudo

# check package ------------------------------------------------------------------------------------
function installed () {
  if [[ ${2} == "single" ]]; then
    echo $(dpkg-query -W -f '${Status}\n' "${1}" 2>&1|awk '{ if ($0 ~ /ok installed/) {print "installed"} else {print "not installed"}}')
  else
    ssh ${2} 'dpkg-query -W '${1}' >/dev/null 2>&1'
    if [[ $? == 0 ]]; then
      echo "installed"
    elif [[ $? == 1 ]]; then
      echo "not installed"
    else
      echo "error"
    fi
  fi
}

# get variable -------------------------------------------------------------------------------------
function get_variable () {  
  variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}") 
  variable_value=$(echo "${variable_value}" | tr -d '"') 
  echo "${variable_value}" 
}
