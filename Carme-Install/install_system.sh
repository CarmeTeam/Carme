#!/bin/bash
#-----------------------------------------------------------------------------------------#
#-------------------------------- SYSTEM installation ------------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic funtions --------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# unset proxy -----------------------------------------------------------------------------
if [[ $http_proxy != "" || $https_proxy != "" ]]; then
    http_proxy=""
    https_proxy=""
fi

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then

  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})

  [[ -z ${CARME_SYSTEM} ]] && die "[install_system.sh]: CARME_SYSTEM not set."
  [[ -z ${CARME_NODE_LIST} ]] && die "[install_system.sh]: CARME_NODE_LIST not set."

else
  die "[install_system.sh]: ${FILE_START_CONFIG} not found."
fi


# configuration starts --------------------------------------------------------------------
log "starting system configuration..."

# update packages -------------------------------------------------------------------------
log "updating packages..."

apt-get update -y

# modify ubuntu 22.04 needrestart ---------------------------------------------------------
if [[ -f /etc/needrestart/needrestart.conf ]]; then
  log "updating needrestart..."

  sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
fi
if [[ ${CARME_SYSTEM} == "multi" ]]; then
  for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
    if ssh $COMPUTE_NODE "test -e /etc/needrestart/needrestart.conf"; then
      ssh "$COMPUTE_NODE" "sed -i '/#\$nrconf{restart} = '\''i'\'';/s/.*/\$nrconf{restart} = '\''a'\'';/' /etc/needrestart/needrestart.conf"
    fi
  done
fi

# check hostname in /etc/hosts ------------------------------------------------------------
log "checking hostname in /etc/hosts..."

if grep -qEh '127.0.1.1' /etc/hosts
then
  HOSTNAME_IN_HOSTS=$(grep -Eh '127.0.1.1' /etc/hosts)
  if ! [[ ${HOSTNAME_IN_HOSTS} == *"$(hostname -s)"* ]]; then
    sed -i "s/${HOSTNAME_IN_HOSTS}/& $(hostname -s)/" /etc/hosts
  fi
else
  echo "" >> /etc/hosts
  echo "127.0.1.1 $(hostname -s)" >> /etc/hosts
fi

# check localhost in /etc/hosts -----------------------------------------------------------
log "checking localhost in /etc/hosts..."

if grep -qEh '127.0.0.1' /etc/hosts
then
  LOCALHOST_IN_HOSTS=$(grep -Eh '127.0.0.1' /etc/hosts)
  if ! [[ ${LOCALHOST_IN_HOSTS} == *"localhost"* ]]; then
    sed -i "s/${LOCALHOST_IN_HOSTS}/& localhost/" /etc/hosts
  fi
else
  echo "" >> /etc/hosts
  echo "127.0.0.1 localhost" >> /etc/hosts
fi

# check ssh connection to localhost / head-node -------------------------------------------
if [[ ${CARME_SYSTEM} == "single" ]]; then
  log "configuring ssh connection to localhost..."

  [[ $(installed "openssh-server" "single") == "not installed" ]] && apt install openssh-server -y
  ssh-keygen -A
  if systemctl cat sshd &>/dev/null
  then
    systemctl restart sshd
    systemctl is-active --quiet sshd || die "[install_system.sh]: sshd.service is not running."
  else
    systemctl restart ssh
    systemctl is-active --quiet ssh || die "[install_system.sh]: ssh.service is not running."
  fi
  [[ -f "${HOME}/.ssh/id_rsa" ]] || ssh-keygen -f "${HOME}/.ssh/id_rsa" -N ""
  grep "$(cat ${HOME}/.ssh/id_rsa.pub)" ${HOME}/.ssh/authorized_keys > /dev/null || cat ${HOME}/.ssh/id_rsa.pub >> ${HOME}/.ssh/authorized_keys
  ssh -o StrictHostKeyChecking=accept-new localhost hostname > /dev/null

elif [[ ${CARME_SYSTEM} == "multi" ]]; then
  log "checking ssh connection from the head-node to the head-node..."

  if ! ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking="no" $(hostname -s) true &>/dev/null
  then
    die "[install_system.sh] ssh to $(hostname -s) failed. Carme-demo requires that you ssh from the head-node to the head-node without a password."
  fi
fi

# check ssh connection to compute nodes ---------------------------------------------------
if [[ ${CARME_SYSTEM} == "multi" ]]; then
  log "checking ssh connection to compute nodes..."

  for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
    if ! ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking="no" $COMPUTE_NODE true &>/dev/null
    then
      die "[install_system.sh] ssh to ${MY_COMPUTE_NODE} failed. Carme-demo requires that you ssh to the compute-nodes without a password."
    fi
  done
fi

# check ssh connection between compute nodes ----------------------------------------------
if [[ ${CARME_SYSTEM} == "multi" ]]; then
  log "checking ssh connection between the compute nodes..."

  for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
    for SUB_COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      if [[ ${COMPUTE_NODE} != ${SUB_COMPUTE_NODE} ]]; then
        if ! ssh $COMPUTE_NODE ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking="no" $SUB_COMPUTE_NODE true &>/dev/null
        then
          die "[install_system.sh] ssh from ${COMPUTE_NODE} to ${SUB_COMPUTE_NODE} failed. Carme-demo requires that you ssh between the compute-nodes without a password."
        fi
      fi
    done
  done
fi

log "system successfully configured."
