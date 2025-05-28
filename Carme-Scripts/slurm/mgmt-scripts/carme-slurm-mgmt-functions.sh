#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# functions needed in slurm user management scripts
#
# COPYRIGHT: Fraunhofer ITWM, 2021
# LICENCE: http://open-carme.org/LICENSE.md 
# CONTACT: info@open-carme.org
#-----------------------------------------------------------------------------------------------------------------------------------


function check_if_slurmctld_node () {
# check if this node is the slurmctld node
# USAGE: check_if_slurmctld_node "${CARME_SLURM_ControlAddr}"

  local THIS_NODE_IPS=( "$(hostname -I)" )

  if [[ ! " ${THIS_NODE_IPS[*]} " =~ ${1} ]]; then
    echo "ERROR: this is not the slurmctld node"
    exit 200
  fi

}


function check_if_user_exists () {
# check if user exists
# USAGE: check_if_user_exists "${SLURMUSER}"

  local USEREXISTS=$(id -u "${1}" > /dev/null 2>&1; echo $?)

  if [[ "${USEREXISTS}" = "1" ]]; then
    echo "ERROR: cannot delete ${1} as it does not exist"
    exit 200
  fi

}


function read_and_check_slurm_limitations () {
# read user limitations from terminal and check if they are vaild
# USAGE: read_and_check_slurm_limitations "${SLURMUSER}" "${SLURMUSER_HELPER[*]}"

  local LBR=" $(echo $'\n> ')"
  local SLURM_ACCOUNTS_AVAIL
  local helper_array
  local value
  local ACCOUNT
  local SLURM_PARTITIONS_AVAIL
  local PARTITION_LIST_HELPER
  local SLURM_PARTITION

  # list avialbale groups of the user(s) --------------------------------------------------------
  echo "available groups for user '${1}'"
  groups "${1}"
  echo ""
  echo ""
  #----------------------------------------------------------------------------------------------

  # determine the slurm account to add the user to ----------------------------------------------
  echo "determine account for '${1}'"

  SLURM_ACCOUNTS_AVAIL=( "$(sacctmgr -n list account format="Account%100")" )
  helper_array=()

  for value in ${SLURM_ACCOUNTS_AVAIL[*]};do
    [[ $value != root ]] && helper_array+=("$value")
  done

  SLURM_ACCOUNTS_AVAIL=("${helper_array[@]}")
  unset helper_array

  for ACCOUNT in ${SLURM_ACCOUNTS_AVAIL[*]};do
    echo "${ACCOUNT}"
  done

  echo ""

  read -rp "enter slurm-account '${1}' is suppost to be added to ${LBR}" CARME_SLURM_ACCOUNT
  if [[ ! "${SLURM_ACCOUNTS_AVAIL[*]}" =~ ${CARME_SLURM_ACCOUNT} ]];then
    echo "ERROR: you did not provide an available slurm account"
    exit 200
  fi
  echo ""
  echo ""
  #----------------------------------------------------------------------------------------------

  # determine if the user should have admin privilidges in slurm or not -------------------------
  echo "determine if '${1}' sould have admin rights in slurm"
  read -rp "options are Admin or None ${LBR}" SLURM_ADMIN_LEVEL
  if [[ "${SLURM_ADMIN_LEVEL}" != "Admin" && "${SLURM_ADMIN_LEVEL}" != "None" ]];then
    echo "ERROR: you can only choose between 'Admin' and 'None'"
    exit 200
  fi
  echo ""
  echo ""
  #----------------------------------------------------------------------------------------------

  # determine the partitions the user should be added to ----------------------------------------
  echo "determine partitions '${1}' is supposed to be added to"
  SLURM_PARTITIONS_AVAIL=( "$(sinfo -h -o "%P")" )
  echo "${SLURM_PARTITIONS_AVAIL[*]}"
  echo ""

  read -rp "enter partitions (separated by comma, no spaces) ${LBR}" SLURM_PARTITION_LIST
  PARTITION_LIST_HELPER="${SLURM_PARTITION_LIST//,/ }"

  for SLURM_PARTITION in ${PARTITION_LIST_HELPER[*]};do
    if [[ ! "${SLURM_PARTITIONS_AVAIL[*]}" =~ ${SLURM_PARTITION} ]];then
      echo "ERROR: you did not provide a valid slurm partition"
      exit 200
    fi
  done

  echo ""
  echo ""
  #----------------------------------------------------------------------------------------------

  # determine additional limitaions for the user ------------------------------------------------
  echo "additional limitations"
  echo "NOTE: As there are a lot of possibilities we cannot check all of them."
  echo "      For more details of additional limitations have a look at the SLURM documentation."
  echo ""
  read -rp "enter addtional limitations if desired [separated by space] ${LBR}" SLURM_ADDITIONAL_LIMITS
  echo ""
  echo ""
  #----------------------------------------------------------------------------------------------

}


function put_together_and_check () {
# put together and check
# USAGE: put_together_and_check put_together_and_check "${SLURMUSER}" "${CARME_SLURM_ClusterName}" "${CARME_SLURM_ACCOUNT}" "${SLURM_ADMIN_LEVEL}" "${SLURM_PARTITION_LIST}" "${SLURM_ADDITIONAL_LIMITS}"

  local LBR=" $(echo $'\n> ')"
  local RESP

  echo "do you want to add ${1} with the following specifications"
  echo "cluster: ${2}"
  echo "account: ${3}"
  echo "admin level: ${4}"
  echo "partition(s): ${5}"

  if [[ -n "${6}" ]];then
    echo "additional limits: ${6}"
  fi
  echo ""

  read -rp "[y|N] ${LBR}" RESP
  if [[ "${RESP}" = "N" ]];then
    exit 200
  elif [[ "${RESP}" != "y" && "${RESP}" != "N" ]];then
    exit 200
  fi

}


function list_slurm_accounts () {
# list all accounts a user belongs to
# USAGE: list_slurm_accounts "${SLURMUSER}"

  local LBR=" $(echo $'\n> ')"
  local ACCOUNTS_HELPER
  local ACCOUNT
  local CARME_SLURM_ACCOUNT

  ACCOUNTS_HELPER=( "$(sacctmgr list -n associations user="${1}" format=Account | tr ' ' '\n' | sort -u | tr '\n' ' ')" )
  if [[ ! ${ACCOUNTS_HELPER[*]} ]];then
    echo "ERROR: '${1}' was not found in the slurm database"
    exit 200
  fi

  echo "determine account for '${1}'"
  echo "NOTE: It is possible that a user belongs to more than one slurm account."
  echo "      Therefore we have to specify the account."

  for ACCOUNT in ${ACCOUNTS_HELPER[*]};do
    echo "${ACCOUNT}"
  done
  echo ""

  read -rp "enter slurm-account you want to delete the user from ${LBR}" CARME_SLURM_ACCOUNT

}
