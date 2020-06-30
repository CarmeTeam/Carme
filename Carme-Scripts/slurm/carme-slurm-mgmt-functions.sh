#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# functions needed in slurm user management scripts
#-----------------------------------------------------------------------------------------------------------------------------------


# default parameters ---------------------------------------------------------------------------------------------------------------
SETCOLOR='\033[01;31m'
NOCOLOR='\033[0m'
LBR=" $(echo $'\n> ')"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if this node is the slurmctld node -----------------------------------------------------------------------------------------
# USAGE: check_if_slurmctld_node "${CARME_SLURM_ControlAddr}"
function check_if_slurmctld_node () {
  THIS_NODE_IPS=( "$(hostname -I)" )
  if [[ ! " ${THIS_NODE_IPS[*]} " =~ ${1} ]]; then
    echo "ERROR: this is not the slurmctld node"
    exit 200
  fi
}
#-----------------------------------------------------------------------------------------------------------------------------------


# check if user exists -------------------------------------------------------------------------------------------------------------
# USAGE: check_if_user_exists "${SLURMUSER}"
function check_if_user_exists () {
  USEREXISTS=$(id -u "${1}" > /dev/null 2>&1; echo $?)
  if [ "${USEREXISTS}" = "1" ]; then
      echo "ERROR: cannot delete ${1} as it does not exist"
      exit 200
  fi
}
#-----------------------------------------------------------------------------------------------------------------------------------


# read user limitations from terminal and check if they are vaild-------------------------------------------------------------------
# USAGE: read_and_check_slurm_limitations "${SLURMUSER}" "${SLURMUSER_HELPER[*]}"
function read_and_check_slurm_limitations () {
    # list avialbale groups of the user(s) --------------------------------------------------------
    echo -e "${SETCOLOR}available groups for user ${1}${NOCOLOR}"
    groups "${1}"
    echo ""
    echo ""
    #----------------------------------------------------------------------------------------------

    # determine the slurm account to add the user to ----------------------------------------------
    echo -e "${SETCOLOR}determine account for ${1}${NOCOLOR}"
    
    SLURM_ACCOUNTS_AVAIL=( "$(sacctmgr -n list account format=Account)" )
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
    
    read -rp "enter slurm-account ${1} is suppost to be added to ${LBR}" CARME_SLURM_ACCOUNT
    if [[ ! "${SLURM_ACCOUNTS_AVAIL[*]}" =~ ${CARME_SLURM_ACCOUNT} ]];then
      echo "ERROR: you did not provide an available slurm account"
      exit 200
    fi
    echo ""
    echo ""
    #----------------------------------------------------------------------------------------------

    # determine if the user should have admin privilidges in slurm or not -------------------------
    echo -e "${SETCOLOR}determine if ${1} sould have admin rights in slurm${NOCOLOR}"
    read -rp "options are Admin or None ${LBR}" SLURM_ADMIN_LEVEL
    if [[ "${SLURM_ADMIN_LEVEL}" != "Admin" && "${SLURM_ADMIN_LEVEL}" != "None" ]];then
      echo "ERROR: you can only choose between 'Admin' and 'None'"
      exit 200
    fi
    echo ""
    echo ""
    #----------------------------------------------------------------------------------------------

    # determine the partitions the user should be added to ----------------------------------------
    echo -e "${SETCOLOR}determine partitions ${1} is supposed to be added to${NOCOLOR}"
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
    echo -e "${SETCOLOR}additional limitations${NOCOLOR}"
    echo "NOTE: As there are a lot of possibilities we cannot check all of them."
    echo "      For more details of additional limitations have a look at the SLURM documentation."
    echo ""
    read -rp "enter addtional limitations if desired [separated by space] ${LBR}" SLURM_ADDITIONAL_LIMITS
    echo ""
    echo ""
    #----------------------------------------------------------------------------------------------
}
#-----------------------------------------------------------------------------------------------------------------------------------


# put together and check -----------------------------------------------------------------------------------------------------------
# USAGE: put_together_and_check put_together_and_check "${SLURMUSER}" "${CARME_SLURM_ClusterName}" "${CARME_SLURM_ACCOUNT}" "${SLURM_ADMIN_LEVEL}" "${SLURM_PARTITION_LIST}" "${SLURM_ADDITIONAL_LIMITS}"
function put_together_and_check () {
  echo -e "${SETCOLOR}do you want to add ${1} with the following specifications${NOCOLOR}"
  echo "cluster: ${2}"
  echo "account: ${3}"
  echo "admin level: ${4}"
  echo "partition(s): ${5}"
  if [[ -n "${6}" ]];then
    echo "additional limits: ${6}"
  fi
  echo ""
  read -rp "[y|N] ${LBR}" RESP

  if [ "$RESP" = "N" ];then
    exit 200
  elif [[ "$RESP" != "y" && "$RESP" != "N" ]];then
    exit 200
  fi
}
#-----------------------------------------------------------------------------------------------------------------------------------


# list all accounts a user belongs to
# USAGE: list_slurm_accounts "${SLURMUSER}"
function list_slurm_accounts () {
  ACCOUNTS_HELPER=( "$(sacctmgr list -n associations user="${1}" format=Account | tr ' ' '\n' | sort -u | tr '\n' ' ')" )
  if [[ ! ${ACCOUNTS_HELPER[*]} ]];then
    echo "ERROR: ${1} is not found in the slurm database, so we cannot delete it"
    exit 200
  fi
  
  echo -e "${SETCOLOR}determine account for ${1}${NOCOLOR}"
  echo "NOTE: It is possible that a user belongs to more than one slurm account."
  echo "      Therefore we have to specify the account."
  
  for ACCOUNT in ${ACCOUNTS_HELPER[*]};do
    echo "${ACCOUNT}"
  done
  echo ""
  
  read -rp "enter slurm-account you want to delete the user from ${LBR}" CARME_SLURM_ACCOUNT
}
#-----------------------------------------------------------------------------------------------------------------------------------
