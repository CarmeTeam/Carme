#!/bin/bash
#-----------------------------------------------------------------------------------------#
#----------------------------------- remove CERTIFICATE ----------------------------------#
#-----------------------------------------------------------------------------------------#


# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail
#------------------------------------------------------------------------------------------

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# uninstall variables ---------------------------------------------------------------------
PATH_CONFIG="${CARME_HOME}/.config"
PATH_USER_SSL="${PATH_CONFIG}/carme/SSL"
PATH_PROXY_SSL="${PATH_CARME}/Carme-Proxy/SSL"
PATH_BACKEND_SSL="${PATH_CARME}/Carme-Backend/SSL"
PATH_SCRIPTS_SSL="${PATH_CARME}/Carme-Scripts/SSL"
PATH_FRONTEND_SSL="${PATH_CARME}/Carme-Frontend/Carme-Django/webfrontend/SSL"

# remove proxy certs ----------------------------------------------------------------------
log "removing proxy certs..."

rm -rf "${PATH_PROXY_SSL}" 

# remove user certs -----------------------------------------------------------------------
log "removing user certs..."

rm -rf "${PATH_USER_SSL}" 

# remove scripts certs --------------------------------------------------------------------
log "removing scripts certs..."

rm -rf "${PATH_SCRIPTS_SSL}"

# remove frontend certs -------------------------------------------------------------------
log "removing frontend certs..."

rm -rf "${PATH_FRONTEND_SSL}"

# remove backend certs --------------------------------------------------------------------
log "removing backend certs..."

rm -rf "${PATH_BACKEND_SSL}"

log "carme-certs successfully removed."
