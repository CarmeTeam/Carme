#!/bin/bash

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# check config ----------------------------------------------------------------------------
[[ -f CarmeConfig.start ]] || die "[start.sh]: CarmeConfig.start was not created. Please, first run \`bash config.sh\`."
[[ -s CarmeConfig.start ]] || die "[start.sh]: CarmeConfig.start was not set properly. Please, first run \`bash config.sh\`."

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  [[ -z ${CARME_SYSTEM} ]] && die "[start.sh]: CARME_SYSTEM not set."
else
  die "[start.sh]: ${FILE_START_CONFIG} not found."
fi

# check config ----------------------------------------------------------------------------
CHECK_CONFIG_MESSAGE=$"
#######################################################
######    Welcome to Carme-demo ${CARME_VERSION} Install    ######
#######################################################

Carme uses the config file ${PATH_CARME}/CarmeConfig.start. 
Please, check this file before proceeding.

Do you want to continue with the installation? [y/N]:"

read -rp "${CHECK_CONFIG_MESSAGE} " REPLY
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  die "[start.sh]: Installation stopped."
fi

# steps ----------------------------------------------------------------------------------
log "installation starts..."

# step 1: install SYSTEM
bash ${PATH_CARME}/Carme-Install/install_system.sh

# step 2: install DATABASE 
bash ${PATH_CARME}/Carme-Install/install_database.sh

# step 3: install SLURM
bash ${PATH_CARME}/Carme-Install/install_slurm.sh

# step 4: install VENDORS
bash ${PATH_CARME}/Carme-Install/install_vendors.sh

# step 5: install CERTS
bash ${PATH_CARME}/Carme-Install/install_certs.sh

# step 6: install FRONTEND
bash ${PATH_CARME}/Carme-Install/install_frontend.sh

# step 7: install BACKEND
bash ${PATH_CARME}/Carme-Install/install_backend.sh

# step 8: install BASE
bash ${PATH_CARME}/Carme-Install/install_base.sh

# step 9: install SCRIPTS
bash ${PATH_CARME}/Carme-Install/install_scripts.sh

# step 10: install PROXY
bash ${PATH_CARME}/Carme-Install/install_proxy.sh

echo "
###########################################################
######    Carme-demo ${CARME_VERSION} successfully installed    ######
###########################################################
"
