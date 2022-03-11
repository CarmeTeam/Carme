#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Copyright 2022 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
#-----------------------------------------------------------------------------------------------------------------------------------


# install miniconda ----------------------------------------------------------------------------------------------------------------
# download miniconda installer
cd /opt || exit 200
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh


# install miniconda
CONDA_INSTALL_PATH="/opt/miniconda3"
bash Miniconda3-latest-Linux-x86_64.sh -b -u -p "${CONDA_INSTALL_PATH}"
rm Miniconda3-latest-Linux-x86_64.sh


# create conda base environment
source "${CONDA_INSTALL_PATH}/etc/profile.d/conda.sh"
conda activate base
conda update -n base -c defaults conda


# install mamba package manager
conda install -y -c conda-forge mamba


# install python packages for formatting and linting
pip install --no-cache-dir autopep8
pip install --no-cache-dir pylint


# clean up
conda clean --all -y
conda deactivate
cd || exit 200
#-----------------------------------------------------------------------------------------------------------------------------------
