#!/bin/bash

# install code-server --------------------------------------------------------------------------------------------------------------

# activate package manager
PACKAGE_INSTALL_PATH="/opt/package-manager"
PATH_TO_CONDA_BIN="${PACKAGE_INSTALL_PATH}/bin/conda"
source "${PACKAGE_INSTALL_PATH}/etc/profile.d/conda.sh"
source "${PACKAGE_INSTALL_PATH}/etc/profile.d/mamba.sh"
mamba activate base


# install code-server
mamba install -y -c conda-forge code-server


# clean up
mamba clean --all -y
#-----------------------------------------------------------------------------------------------------------------------------------

