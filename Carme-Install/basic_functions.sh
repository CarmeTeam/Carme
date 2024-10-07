#!/bin/bash
#--------------------------------------------------------------------------------------------------#
#----------------------------------------- Basic Functions  ---------------------------------------#
#--------------------------------------------------------------------------------------------------#

# show version -------------------------------------------------------------------------------------
CARME_VERSION="v0.99"

SYSTEM_DIST=$(awk -F= '$1=="ID" { gsub(/"/, "", $2); print $2 ;}' /etc/os-release)
if ! [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" || $SYSTEM_DIST == "rocky"  ]];then
  die "[config.sh]: ubuntu, debian, and rocky distros are supported. Yours is ${SYSTEM_DIST}. Please contact us."
fi

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

function update_packages () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    apt-get update -y
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    dnf check-update -y || true
  fi
}

function install_packages () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    apt install -y "${@}"
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    dnf install -y "${@}"
  fi
}

function install_packages_remote () {
  COMPUTE_NODE="$1"; shift
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    ssh -t $COMPUTE_NODE "apt install $@ -y"
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    ssh -t $COMPUTE_NODE "dnf install $@ -y"
  fi
}

function remove_packages () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    apt remove --purge -y "${@}"
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    dnf remove -y "${@}"
  fi
}

function remove_packages_remote () {
  COMPUTE_NODE="$1"; shift
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    ssh -t $COMPUTE_NODE "apt remove --purge $@ -y"
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    ssh -t $COMPUTE_NODE "dnf remove $@ -y"
  fi
}

function list_packages_files () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    dpkg -L "${@}"
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    dnf repoquery -l "${@}"
  fi
}

function autoremove_packages () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    apt autoremove -y
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    dnf autoremove -y
  fi
}

function clean_packages () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    apt clean
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    dnf clean all
  fi
}

function autoclean_packages () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    apt autoclean
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    dnf clean all
  fi
}

function reconfigure_packages () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    dpkg --configure -a
  fi
  # TODO: is there an equivalent for rocky?
}

function reconfigure_packages_remote () {
  COMPUTE_NODE="$1"
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    ssh -t $COMPUTE_NODE "dpkg --configure -a"
  fi
  # TODO: is there an equivalent for rocky?
}

# check command ------------------------------------------------------------------------------------
function check_command () {
  if ! command -v "${1}" >/dev/null 2>&1 ;then
    install_packages "${1}"
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

function check_install () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    echo $(dpkg-query -W -f '${Status}\n' "${1}" 2>&1|awk '{ if ($0 ~ /ok installed/) {print "installed"} else {print "not installed"}}')
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    echo $(dnf list "${1}" 2>&1|awk '/Installed Packages/ {print "installed"; found=1; exit}; END {if (found) exit; print "not installed"}')
  fi
}

function check_install_remote () {
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    ssh ${2} 'dpkg-query -W '${1}' >/dev/null 2>&1'
    if [[ $? == 0 ]]; then
      echo "installed"
    elif [[ $? == 1 ]]; then
      echo "not installed"
    else
      echo "error"
    fi
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    dnf_output=$(ssh ${2} 'dnf list '${1}' >/dev/null 2>&1')
    if [[ $? != 0 ]]; then
      echo "error"
    else
      echo "$dnf_output"|awk '/Installed Packages/ {print "installed"; found=1; exit}; END {if (found) exit; print "not installed"}'
    fi
  fi
}

# check package ------------------------------------------------------------------------------------
function installed () {
  if [[ ${2} == "single" ]]; then
    check_install "${1}"
  else
    check_install_remote "${1}" "${2}"
  fi
}

# get variable -------------------------------------------------------------------------------------
function get_variable () {  
  variable_value=$(grep --color=never -Po "^${1}=\K.*" "${2}") 
  variable_value=$(echo "${variable_value}" | tr -d '"') 
  echo "${variable_value}" 
}
