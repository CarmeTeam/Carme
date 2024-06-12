#!/bin/bash
#-----------------------------------------------------------------------------------------#
#-------------------------------- BASE installation --------------------------------------#
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

  MAMBAFORGE_VERSION=$(get_variable MAMBAFORGE_VERSION ${FILE_START_CONFIG})

  [[ -z ${MAMBAFORGE_VERSION} ]] && die "[install_base.sh]: MAMBAFORGE_VERSION not set."

else
  die "[install_base.sh]: ${FILE_START_CONFIG} not found."
fi

# install variables ----------------------------------------------------------------------

PATH_SINGULARITY=${PATH_CARME}/Carme-Vendors/singularity/bin
PATH_BASE_CONTAINERIMAGE=${PATH_CARME}/Carme-ContainerImages/Carme-Base-Image

FILE_SINGULARITY=${PATH_SINGULARITY}/singularity
FILE_INSTALL_APT=${PATH_BASE_CONTAINERIMAGE}/install-scripts/install_apt.sh
FILE_INSTALL_GPI=${PATH_BASE_CONTAINERIMAGE}/install-scripts/install_gpi.sh
FILE_SET_DEFAULT_CONDA=${PATH_BASE_CONTAINERIMAGE}/install-scripts/set_default_conda.sh
FILE_INSTALL_MINICONDA=${PATH_BASE_CONTAINERIMAGE}/install-scripts/install_miniconda.sh
FILE_INSTALL_MAMBAFORGE=${PATH_BASE_CONTAINERIMAGE}/install-scripts/install_mambaforge.sh
FILE_INSTALL_CODESERVER=${PATH_BASE_CONTAINERIMAGE}/install-scripts/install_codeserver.sh
FILE_INSTALL_JUPYTERLAB=${PATH_BASE_CONTAINERIMAGE}/install-scripts/install_jupyterlab.sh

# check singularity -----------------------------------------------------------------------
if ! command -v "${FILE_SINGULARITY}" >/dev/null 2>&1; then
    die "[install_base.sh]: Singularity is not installed in ${PATH_SINGULARITY}."
fi

# check compatibility ---------------------------------------------------------------------
log "checking system..."

SYSTEM_ARCH=$(dpkg --print-architecture)
if ! [[ $SYSTEM_ARCH == "arm64" || $SYSTEM_ARCH == "amd64"  ]];then
  die "[install_base.sh]: amd64 and arm64 architectures are supported. Yours is $SYSTEM_ARCH. Please contact us."
fi

SYSTEM_HDWR=$(uname -m)
if ! [[ $SYSTEM_HDWR == "aarch64" || $SYSTEM_HDWR == "x86_64"  ]];then
  die "[install_base.sh]: aarch64 and x86_64 hardwares are supported. Yours is $SYSTEM_HDWR. Please contact us."
fi

SYSTEM_OS=$(uname -s)
if ! [ ${SYSTEM_OS,} = "linux" ]; then
  die "[install_base.sh]: linux OS is supported. Yours is ${SYSTEM_OS,}. Please contact us."
fi

# unset proxy if exists -------------------------------------------------------------------
log "unsetting proxy if exists..."
if [[ $http_proxy != "" || $https_proxy != "" ]]; then
    http_proxy=""
    https_proxy=""
fi

# installation starts ---------------------------------------------------------------------
log "starting base installation..."


# create base directory -------------------------------------------------------------------
log "creating base directories..."

mkdir -p /home/carme-container
ln -sf "${PATH_BASE_CONTAINERIMAGE}/base.sif" /home/carme-container/base.sif

############################ starts install-scripts #######################################

mkdir -p ${PATH_BASE_CONTAINERIMAGE}/install-scripts

# create install_apt.sh -------------------------------------------------------------------

[[ -f "${FILE_INSTALL_APT}" ]] && rm "${FILE_INSTALL_APT}"
touch ${FILE_INSTALL_APT}
cat << EOF >> ${FILE_INSTALL_APT}
#!/bin/bash
#------------------------------------------------------------------------------------------
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_base.sh
# Copyright 2024 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# install_apt.sh
#------------------------------------------------------------------------------------------

# add repo --------------------------------------------------------------------------------
echo "deb http://security.debian.org/debian-security stable-security main" >> /etc/apt/sources.list

# update repo -----------------------------------------------------------------------------
apt update
apt upgrade -y

# install basic ---------------------------------------------------------------------------
apt install -y bash-completion fd-find fzf htop less locales man-db nano rsync screen time tmux unzip vim wget zip
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales

# install ssh -----------------------------------------------------------------------------
apt install -y openssh-server

# install tools ---------------------------------------------------------------------------
apt install -y automake build-essential cmake colordiff g++ gawk gcc gdb gfortran git shellcheck

# install openmpi -------------------------------------------------------------------------
apt install -y openmpi-bin libopenmpi-dev

# install infiniband ----------------------------------------------------------------------
apt install -y libibverbs1 libibverbs-dev librdmacm1 libibmad5 libibumad3 librdmacm1 \
ibverbs-providers rdmacm-utils infiniband-diags libfabric1 ibverbs-utils

# clean up --------------------------------------------------------------------------------
apt autoremove --purge -y
apt clean
EOF

# create install_gpi.sh -------------------------------------------------------------------

[[ -f "${FILE_INSTALL_GPI}" ]] && rm "${FILE_INSTALL_GPI}"
touch ${FILE_INSTALL_GPI}
cat << EOF >> ${FILE_INSTALL_GPI}
#!/bin/bash
#------------------------------------------------------------------------------------------
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_base.sh
# Copyright 2024 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# install_gpi.sh
#------------------------------------------------------------------------------------------

# install system dependencies -------------------------------------------------------------
apt install -y libtool

# git clone repo --------------------------------------------------------------------------
GPI_VERSION="v1.5.1"
cd /opt || exit 200
git clone --branch "\${GPI_VERSION}" --depth 1 https://github.com/cc-hpc-itwm/GPI-2.git GPI-SRC

# build gpi -------------------------------------------------------------------------------
GPI_INSTALL_PATH="/opt/GPI"
cd /opt/GPI-SRC || exit 200
./autogen.sh
CC=gcc FC=gfortran CFLAGS="-fPIC" CPPFLAGS="-fPIC" ./configure --with-infiniband --prefix="\${GPI_INSTALL_PATH}"
make -j 20
make install
cd || exit 200
rm -r /opt/GPI-SRC

# modify 'gaspi_run' and 'gaspi_cleanup' to match our ssh setup ---------------------------
sed -i 's/GASPI_LAUNCHER="ssh"/GASPI_LAUNCHER="ssh -F \${CARME_SSHDIR}\/ssh_config"/g' "\${GPI_INSTALL_PATH}/bin/gaspi_run"
sed -i 's/ssh/ssh -F \${CARME_SSHDIR}\/ssh_config/g' "\${GPI_INSTALL_PATH}/bin/gaspi_cleanup"

# create links in /usr/local --------------------------------------------------------------
ln -s "\${GPI_INSTALL_PATH}/bin/gaspi_cleanup" /usr/local/bin/gaspi_cleanup
ln -s "\${GPI_INSTALL_PATH}/bin/gaspi_logger" /usr/local/bin/gaspi_logger
ln -s "\${GPI_INSTALL_PATH}/bin/ssh.spawner" /usr/local/bin/ssh.spawner
ln -s "\${GPI_INSTALL_PATH}/bin/gaspi_run" /usr/local/bin/gaspi_run
ln -s "\${GPI_INSTALL_PATH}"/include/* /usr/local/include/

mkdir -p /usr/local/lib64
ln -s "\${GPI_INSTALL_PATH}"/lib64/* /usr/local/lib64/

rm /usr/local/lib64/pkgconfig
mkdir -p /usr/local/lib64/pkgconfig
ln -s "\${GPI_INSTALL_PATH}"/lib64/pkgconfig/* /usr/local/lib64/pkgconfig

# clean up --------------------------------------------------------------------------------
apt autoremove --purge -y
apt clean
EOF

# create install_miniconda.sh ------------------------------------------------------------

[[ -f "${FILE_INSTALL_MINICONDA}" ]] && rm "${FILE_INSTALL_MINICONDA}"
touch ${FILE_INSTALL_MINICONDA}
cat << EOF >> ${FILE_INSTALL_MINICONDA}
#!/bin/bash
#------------------------------------------------------------------------------------------
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_base.sh
# Copyright 2024 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# install_miniconda.sh
#------------------------------------------------------------------------------------------

# download installer ----------------------------------------------------------------------
cd /opt  || exit 200
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-$SYSTEM_OS-$SYSTEM_HDWR.sh

# install mambaforge ----------------------------------------------------------------------
PATH_MINICONDA="/opt/miniconda3"
bash Miniconda3-latest-$SYSTEM_OS-$SYSTEM_HDWR.sh -b -u -p \${PATH_MINICONDA}
rm Miniconda3-latest-$SYSTEM_OS-$SYSTEM_HDWR.sh

# create base environment -----------------------------------------------------------------
source "\${PATH_MINICONDA}/etc/profile.d/conda.sh"
conda activate base
conda update -n base -c defaults conda

# add mamba package manager ---------------------------------------------------------------
conda install -y -c conda-forge mamba

# install python packages for formatting and linting --------------------------------------
pip install --no-cache-dir autopep8
pip install --no-cache-dir pylint

# clean up --------------------------------------------------------------------------------
conda clean --all -y
conda deactivate
cd  || exit 200
EOF

# create install_mambaforge.sh ------------------------------------------------------------

[[ -f "${FILE_INSTALL_MAMBAFORGE}" ]] && rm "${FILE_INSTALL_MAMBAFORGE}"
touch ${FILE_INSTALL_MAMBAFORGE}
cat << EOF >> ${FILE_INSTALL_MAMBAFORGE}
#!/bin/bash
#------------------------------------------------------------------------------------------
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_base.sh
# Copyright 2024 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# install_mambaforge.sh
#------------------------------------------------------------------------------------------

# download installer ----------------------------------------------------------------------
cd /opt  || exit 200
wget https://github.com/conda-forge/miniforge/releases/download/$MAMBAFORGE_VERSION/Mambaforge-$MAMBAFORGE_VERSION-$SYSTEM_OS-$SYSTEM_HDWR.sh

# install mambaforge ----------------------------------------------------------------------
PATH_MAMBAFORGE="/opt/mambaforge"
bash Mambaforge-$MAMBAFORGE_VERSION-$SYSTEM_OS-$SYSTEM_HDWR.sh -b -u -p \${PATH_MAMBAFORGE}
rm Mambaforge-$MAMBAFORGE_VERSION-$SYSTEM_OS-$SYSTEM_HDWR.sh

# create base environment -----------------------------------------------------------------
source "\${PATH_MAMBAFORGE}/etc/profile.d/conda.sh"
source "\${PATH_MAMBAFORGE}/etc/profile.d/mamba.sh"
mamba activate base
mamba update -n base -y mamba

# install python packages for formatting and linting --------------------------------------
pip install --no-cache-dir autopep8
pip install --no-cache-dir pylint

# clean up --------------------------------------------------------------------------------
mamba clean --all -y
mamba deactivate
cd  || exit 200
EOF

# create set_default_conda.sh -------------------------------------------------------------

[[ -f "${FILE_SET_DEFAULT_CONDA}" ]] && rm "${FILE_SET_DEFAULT_CONDA}"
touch ${FILE_SET_DEFAULT_CONDA}
cat << EOF >> ${FILE_SET_DEFAULT_CONDA}
#!/bin/bash
#------------------------------------------------------------------------------------------
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_base.sh
# Copyright 2024 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# set_default_conda.sh
#------------------------------------------------------------------------------------------

# set default conda -----------------------------------------------------------------------

if [[ "\${1}" == "miniconda" ]];then

  # set miniconda as default
  cd /opt || exit 200
  ln -s /opt/miniconda3 /opt/package-manager

elif [[ "\${1}" == "mambaforge" ]];then

  # set mambaforge as default
  cd /opt || exit 200
  ln -s /opt/mambaforge /opt/package-manager

fi
EOF

# create install_jupyterlab.sh ------------------------------------------------------------

[[ -f "${FILE_INSTALL_JUPYTERLAB}" ]] && rm "${FILE_INSTALL_JUPYTERLAB}"
touch ${FILE_INSTALL_JUPYTERLAB}
cat << EOF >> ${FILE_INSTALL_JUPYTERLAB}
#!/bin/bash
#------------------------------------------------------------------------------------------
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_base.sh
# Copyright 2024 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# install_jupyterlab.sh
#------------------------------------------------------------------------------------------

# activate package manager ----------------------------------------------------------------
PACKAGE_INSTALL_PATH="/opt/package-manager"
[[ -f "\${PACKAGE_INSTALL_PATH}/etc/profile.d/conda.sh" ]] && source "\${PACKAGE_INSTALL_PATH}/etc/profile.d/conda.sh"
[[ -f "\${PACKAGE_INSTALL_PATH}/etc/profile.d/mamba.sh" ]] && source "\${PACKAGE_INSTALL_PATH}/etc/profile.d/mamba.sh"

# check mamba and conda -------------------------------------------------------------------
if command -v "mamba" >/dev/null 2>&1 ;then
  PACKAGE_MANAGER="mamba"
elif command -v "conda" >/dev/null 2>&1 ;then
  PACKAGE_MANAGER="conda"
else
  echo "ERROR: neither 'mamba' nor 'conda' seams to be installed"
  exit 200
fi

# activate base environment ---------------------------------------------------------------
"\${PACKAGE_MANAGER}" activate base

# install jupyterlab ----------------------------------------------------------------------
"\${PACKAGE_MANAGER}" install -y -c conda-forge jupyterlab nb_conda_kernels

# modify jupyterlab settings --------------------------------------------------------------
mkdir "\${PACKAGE_INSTALL_PATH}/share/jupyter/lab/settings"

echo "{
  \"@jupyterlab/notebook-extension:tracker\": {
    \"kernelShutdown\": true
  },
  \"@jupyterlab/terminal-extension:plugin\": {
    \"shutdownOnClose\": true
  }
}" > "\${PACKAGE_INSTALL_PATH}/share/jupyter/lab/settings/overrides.json"


echo "{
  \"disabledExtensions\": [ \"@jupyterlab/extensionmanager-extension\" ]
}
" > "\${PACKAGE_INSTALL_PATH}/share/jupyter/lab/settings/page_config.json"

# clean up --------------------------------------------------------------------------------
"\${PACKAGE_MANAGER}" clean --all -y
EOF

# create install_codeserver.sh ------------------------------------------------------------

[[ -f "${FILE_INSTALL_CODESERVER}" ]] && rm "${FILE_INSTALL_CODESERVER}"
touch ${FILE_INSTALL_CODESERVER}
cat << EOF >> ${FILE_INSTALL_CODESERVER}
#!/bin/bash
#------------------------------------------------------------------------------------------
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_base.sh
# Copyright 2024 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# install_condeserver.sh
#------------------------------------------------------------------------------------------

# activate package manager ----------------------------------------------------------------
PACKAGE_INSTALL_PATH="/opt/package-manager"
PATH_TO_CONDA_BIN="\{PACKAGE_INSTALL_PATH}/bin/conda" 
[[ -f "\${PACKAGE_INSTALL_PATH}/etc/profile.d/conda.sh" ]] && source "\${PACKAGE_INSTALL_PATH}/etc/profile.d/conda.sh"
[[ -f "\${PACKAGE_INSTALL_PATH}/etc/profile.d/mamba.sh" ]] && source "\${PACKAGE_INSTALL_PATH}/etc/profile.d/mamba.sh"

# check mamba and conda -------------------------------------------------------------------
if command -v "mamba" >/dev/null 2>&1 ;then
  PACKAGE_MANAGER="mamba"
elif command -v "conda" >/dev/null 2>&1 ;then
  PACKAGE_MANAGER="conda"
else
  echo "ERROR: neither 'mamba' nor 'conda' seams to be installed"
  exit 200
fi

# activate base environment ---------------------------------------------------------------
"\${PACKAGE_MANAGER}" activate base

# install codeserver ----------------------------------------------------------------------
"\${PACKAGE_MANAGER}" install -y -c conda-forge code-server

# clean up --------------------------------------------------------------------------------
"\${PACKAGE_MANAGER}" clean --all -y
EOF

############################# ends install-scripts ########################################

# build base image ------------------------------------------------------------------------
log "building base image..."

if [[ $(installed "debootstrap" "single") == "not installed" ]]; then
  apt install debootstrap -y
fi

log "initializing build (please wait)..."
cd "${PATH_BASE_CONTAINERIMAGE}"
${FILE_SINGULARITY} build "/tmp/base.sif" "base.recipe"
[[ -f "base.sif" ]] && mv "base.sif" "base.sif.bak"
mv "/tmp/base.sif" "base.sif"
rm -rf install-scripts 

log "carme-base successfully installed."
