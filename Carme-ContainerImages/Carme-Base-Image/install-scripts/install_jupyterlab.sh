#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Copyright 2022 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
#-----------------------------------------------------------------------------------------------------------------------------------


# install jupyterlab ---------------------------------------------------------------------------------------------------------------

# activate package manager
PACKAGE_INSTALL_PATH="/opt/package-manager"
[[ -f "${PACKAGE_INSTALL_PATH}/etc/profile.d/conda.sh" ]] && source "${PACKAGE_INSTALL_PATH}/etc/profile.d/conda.sh"
[[ -f "${PACKAGE_INSTALL_PATH}/etc/profile.d/mamba.sh" ]] && source "${PACKAGE_INSTALL_PATH}/etc/profile.d/mamba.sh"


if command -v "mamba" >/dev/null 2>&1 ;then
  PACKAGE_MANAGER="mamba"
elif command -v "conda" >/dev/null 2>&1 ;then
  PACKAGE_MANAGER="conda"
else
  echo "ERROR: neither 'mamba' nor 'conda' seams to be installed"
  exit 200
fi


# activate base environment
"${PACKAGE_MANAGER}" activate base


# install jupyterlab
"${PACKAGE_MANAGER}" install -y -c conda-forge jupyterlab nb_conda_kernels


# overwrite jupyterlab default settings
mkdir "${PACKAGE_INSTALL_PATH}/share/jupyter/lab/settings"

echo "{
  \"@jupyterlab/notebook-extension:tracker\": {
    \"kernelShutdown\": true
  },
  \"@jupyterlab/terminal-extension:plugin\": {
    \"shutdownOnClose\": true
  }
}" > "${PACKAGE_INSTALL_PATH}/share/jupyter/lab/settings/overrides.json"


echo "{
  \"disabledExtensions\": [ \"@jupyterlab/extensionmanager-extension\" ]
}
" > "${PACKAGE_INSTALL_PATH}/share/jupyter/lab/settings/page_config.json"


# clean up
"${PACKAGE_MANAGER}" clean --all -y
#-----------------------------------------------------------------------------------------------------------------------------------
