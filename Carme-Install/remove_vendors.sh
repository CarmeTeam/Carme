#!/bin/bash
#-----------------------------------------------------------------------------------------#
#------------------------------------ remove VENDORS -------------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# uninstall variables ---------------------------------------------------------------------
PATH_VENDORS=${PATH_CARME}/Carme-Vendors
PATH_SINGULARITY=${PATH_VENDORS}/singularity
PATH_MAMBAFORGE=${PATH_VENDORS}/mambaforge
PATH_GO=${PATH_VENDORS}/go

# remove mambaforge -----------------------------------------------------------------------
log "removing mambaforge..."

rm -rf ${PATH_MAMBAFORGE}

# remove singularity ----------------------------------------------------------------------
log "removing singularity..."

rm -rf ${PATH_SINGULARITY}

# remove go -------------------------------------------------------------------------------
log "removing go..."

rm -rf ${PATH_GO}
if grep -Fxq "export PATH=\$PATH:${PATH_GO}/bin" ~/.bashrc
then
  sed -i 's/export PATH=$PATH:\/opt\/Carme\/Carme-Vendors\/go\/bin//' ~/.bashrc
fi
eval "$(cat ~/.bashrc | tail -n +10)"

# remove vendors directory ----------------------------------------------------------------
log "removing vendors directory..."

rm -rf ${PATH_VENDORS}

log "carme-vendors successfully removed."
