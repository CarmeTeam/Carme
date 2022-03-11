#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Copyright 2022 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
#-----------------------------------------------------------------------------------------------------------------------------------


# install mambaforge ---------------------------------------------------------------------------------------------------------------
# download mambaforge installer
cd /opt  || exit 200
wget https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh


# install mambaforge
MAMBA_INSTALL_PATH="/opt/mambaforge"
bash Mambaforge-Linux-x86_64.sh -b -u -p "${MAMBA_INSTALL_PATH}"
rm Mambaforge-Linux-x86_64.sh


# create base environment
source "${MAMBA_INSTALL_PATH}/etc/profile.d/conda.sh"
source "${MAMBA_INSTALL_PATH}/etc/profile.d/mamba.sh"
mamba activate base
mamba update -n base -y mamba


# install python packages for formatting and linting
pip install --no-cache-dir autopep8
pip install --no-cache-dir pylint


# clean up
mamba clean --all -y
mamba deactivate
cd  || exit 200
#-----------------------------------------------------------------------------------------------------------------------------------
