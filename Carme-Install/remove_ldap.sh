#!/bin/bash
#-----------------------------------------------------------------------------------------#
#----------------------------------- remove LDAP -----------------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then

  CARME_LDAP=$(get_variable CARME_LDAP ${FILE_START_CONFIG})
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})

  [[ -z ${CARME_LDAP} ]] && die "[remove_ldap.sh]: CARME_LDAP not set."
  [[ -z ${CARME_SYSTEM} ]] && die "[remove_ldap.sh]: CARME_SYSTEM not set."
  [[ -z ${CARME_NODE_LIST} ]] && die "[remove_ldap.sh]: CARME_NODE_LIST not set."

else
  die "[remove_ldap.sh]: ${FILE_START_CONFIG} not found."
fi

# check variables --------------------------------------------------------------------------
log "checking variables..."

if ! [[ ${CARME_SYSTEM} == "single" || ${CARME_SYSTEM} == "multi" ]]; then
  die "[remove_ldap.sh]: CARME_SYSTEM in CarmeConfig.start was not set properly. It must be single or multi."
fi
if ! [[ ${CARME_LDAP} == "yes" || ${CARME_LDAP} == "no" || ${CARME_LDAP} == "null" ]]; then
  die "[remove_ldap.sh]: CARME_LDAP in CarmeConfig.start was not set properly. It must be yes or no or null."
fi

# remove packages -------------------------------------------------------------------------

if [[ ${CARME_LDAP} == "yes" ]]; then
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    log "removing ldap packages..."
    DEBIAN_FRONTEND=noninteractive apt purge --auto-remove slapd ldapscripts libnss-ldapd -y
    log "slurm successfully removed."
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    log "removing ldap packages in the head-node..."
    DEBIAN_FRONTEND=noninteractive apt purge --auto-remove slapd ldapscripts libnss-ldapd -y

    for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      log "removing ldap packages in the compute-node ${COMPUTE_NODE}..."
      ssh ${COMPUTE_NODE} "DEBIAN_FRONTEND=noninteractive apt purge --auto-remove libnss-ldapd -y"
    done
    log "ldap successfully removed."
  fi
elif [[ ${CARME_LDAP} == "no" ]]; then
  log "carme in ldap successfully removed."
elif [[ ${CARME_LDAP} == "null" ]]; then
  log "carme in ldap successfully removed."
fi
