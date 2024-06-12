#!/bin/bash
#-----------------------------------------------------------------------------------------#
#------------------------------------ remove BASE ----------------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# uninstall variables ---------------------------------------------------------------------
PATH_BASE_CONTAINERIMAGE=${PATH_CARME}/Carme-ContainerImages/Carme-Base-Image

# remove base image -----------------------------------------------------------------------
log "removing base image..."

rm -f "${PATH_BASE_CONTAINERIMAGE}/base.sif"
rm -f "${PATH_BASE_CONTAINERIMAGE}/base.sif.bak"

# remove base directory -------------------------------------------------------------------
log "removing directories..."

rm -rf /home/carme-container

log "carme-base successfully removed."

