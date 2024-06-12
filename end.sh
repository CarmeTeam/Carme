#!/bin/bash

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# check config ----------------------------------------------------------------------------
[[ -f CarmeConfig.start ]] || die "[end.sh]: CarmeConfig.start does not exist."
[[ -s CarmeConfig.start ]] || die "[end.sh]: CarmeConfig.start was not set properly."

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

CARME_DB=$(get_variable CARME_DB ${FILE_START_CONFIG})
CARME_SLURM=$(get_variable CARME_SLURM ${FILE_START_CONFIG})
CARME_DB_SERVER=$(get_variable CARME_DB_SERVER ${FILE_START_CONFIG})

[[ -z ${CARME_DB} ]] && die "[end.sh]: CARME_DB not set."
[[ -z ${CARME_SLURM} ]] && die "[end.sh]: CARME_SLURM not set."
[[ -z ${CARME_DB_SERVER} ]] && die "[end.sh]: CARME_DB_SERVER not set."

# confirm uninstall -----------------------------------------------------------------------
if [[ ${CARME_DB_SERVER} == "mysql" ]]; then
  CARME_SERVER="MySQL"
elif [[ ${CARME_DB_SERVER} == "mariadb" ]]; then
  CARME_SERVER="MariaDB"
else
  die "[end.sh]: CARME_DB_SERVER in CarmeConfig.start is not properly set. It must be mysql or mariadb."
fi

if [[ ${CARME_DB} == "no" && ${CARME_SLURM} == "yes" ]]; then
  EXCEPTION_MESSAGE="

NOTE: CARME_DB=no in CarmeConfig.start.
${CARME_SERVER} won't be removed. Only Carme tables will be removed."
elif [[ ${CARME_SLURM} == "no" && ${CARME_DB} == "yes" ]]; then
  EXCEPTION_MESSAGE="

NOTE: CARME_SLURM=no in CarmeConfig.start.
SLURM won't be removed. Only Carme scripts will be removed."
elif [[ ${CARME_SLURM} == "no" && ${CARME_DB} == "no" ]]; then
  EXCEPTION_MESSAGE="

NOTE: CARME_DB=no and CARME_SLURM=no in CarmeConfig.start.
${CARME_SERVER} won't be removed. Only Carme tables will be removed.
SLURM won't be removed. Only Carme scripts will be removed."
fi

UNINSTALL_MESSAGE=$"
#########################################################
######    Welcome to Carme-demo ${CARME_VERSION} Uninstall    ######
#########################################################

Carme-demo will be removed from your system. ${EXCEPTION_MESSAGE}

Do you want to proceed? [y/N]:"

read -rp "${UNINSTALL_MESSAGE} " REPLY
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  die "[end.sh]: Uninstall stopped."
fi

# steps -----------------------------------------------------------------------------------
log "uninstallation starts..."

# step 1: uninstall PROXY 
bash ${PATH_CARME}/Carme-Install/remove_proxy.sh

# step 2: uninstall BASE
bash ${PATH_CARME}/Carme-Install/remove_base.sh

# step 3: uninstall BACKEND
bash ${PATH_CARME}/Carme-Install/remove_backend.sh

# step 4: uninstall FRONTEND
bash ${PATH_CARME}/Carme-Install/remove_frontend.sh

# step 5: uninstall CERTS
bash ${PATH_CARME}/Carme-Install/remove_certs.sh

# step 6: uninstall VENDORS
bash ${PATH_CARME}/Carme-Install/remove_vendors.sh

# step 7: uninstall SLURM
bash ${PATH_CARME}/Carme-Install/remove_slurm.sh

# step 8: uninstall DATABASE
bash ${PATH_CARME}/Carme-Install/remove_database.sh

echo "
#########################################################
######    Carme-demo ${CARME_VERSION} successfully removed    ######
#########################################################

NOTE: Remove the /opt/Carme directory... Bye bye.
"

