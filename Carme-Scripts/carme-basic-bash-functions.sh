#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# basic bash functions needed in CARME
#
# COPYRIGHT: Fraunhofer ITWM, 2021
# LICENCE: http://open-carme.org/LICENSE.md 
# CONTACT: info@open-carme.org
#-----------------------------------------------------------------------------------------------------------------------------------


function is_bash () {
# check if bash is used to execute the script
# USAGE: is_bash

  if [[ ! "${BASH_VERSION}" ]]; then
    echo "ERROR: This is a bash-script. Please use bash to execute it!"
    exit 200
  fi

}


function is_root () {
# check if root executes this script
# USAGE: is_root

  if [[ ! "$(whoami)" = "root" ]]; then
    echo "ERROR: you need root privileges to run this script"
    exit 200
  fi

}


function check_command () {
# define function that checks if a command is available or not
# USAGE: check_command COMMAND_NAME

  if ! command -v "${1}" >/dev/null 2>&1 ;then
    echo "ERROR: command '${1}' not found"
    exit 200
  fi

}


function get_variable () {
# get_variable function
# USAGE: get_variable CARME_VARIABLE

  local CONFIG_FILE="/etc/carme/CarmeConfig"

  if [[ ! -f "${CONFIG_FILE}" ]];then
    echo "ERROR: no config-file ('${CONFIG_FILE}') not found"
    exit 200
  fi

  check_command grep

  variable_value=$(grep --color=never -Po "^${1}=\K.*" "${CONFIG_FILE}")
  variable_value=$(echo "${variable_value}" | tr -d '"')
  echo "${variable_value}"

}
