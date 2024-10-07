#!/bin/bash
#-----------------------------------------------------------------------------------------#
#------------------------------ VENDORS installation -------------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# unset proxy -----------------------------------------------------------------------------
if [[ $http_proxy != "" || $https_proxy != "" ]]; then
    http_proxy=""
    https_proxy=""
fi

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then
  
  SYSTEM_OS=$(get_variable SYSTEM_OS ${FILE_START_CONFIG})
  GO_VERSION=$(get_variable GO_VERSION ${FILE_START_CONFIG})
  SYSTEM_ARCH=$(get_variable SYSTEM_ARCH ${FILE_START_CONFIG})
  SYSTEM_HDWR=$(get_variable SYSTEM_HDWR ${FILE_START_CONFIG})
  MAMBAFORGE_VERSION=$(get_variable MAMBAFORGE_VERSION ${FILE_START_CONFIG})
  SINGULARITY_VERSION=$(get_variable SINGULARITY_VERSION ${FILE_START_CONFIG})

  [[ -z ${SYSTEM_OS} ]] && die "[install_vendors.sh]: SYSTEM_OS not set."
  [[ -z ${GO_VERSION} ]] && die "[install_vendors.sh]: GO_VERSION not set."
  [[ -z ${SYSTEM_ARCH} ]] && die "[install_vendors.sh]: SYSTEM_ARCH not set."
  [[ -z ${SYSTEM_HDWR} ]] && die "[install_vendors.sh]: SYSTEM_HDWR not set."
  [[ -z ${MAMBAFORGE_VERSION} ]] && die "[install_vendors.sh]: MAMBAFORGE_VERSION not set."
  [[ -z ${SINGULARITY_VERSION} ]] && die "[install_vendors.sh]: SINGULARITY_VERSION not set."

else
  die "[install_vendors.sh]: ${FILE_START_CONFIG} not found."
fi

# install variables ----------------------------------------------------------------------

PATH_VENDORS=${PATH_CARME}/Carme-Vendors
PATH_SINGULARITY=${PATH_VENDORS}/singularity
PATH_MAMBAFORGE=${PATH_VENDORS}/mambaforge
PATH_GO=${PATH_VENDORS}/go

# installation starts ---------------------------------------------------------------------
log "starting vendors installation..."

# install packages ------------------------------------------------------------------------
log "installing packages..."

if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
  apt-get install -y build-essential libseccomp-dev libglib2.0-dev \
                     pkg-config squashfs-tools cryptsetup wget
elif [[ $SYSTEM_DIST == "rocky" ]]; then
  dnf groupinstall -y "Development Tools"
  dnf install -y libseccomp-devel glib2-devel wget
fi

# create vendors directory ---------------------------------------------------------------- 
log "creating vendors directory..."

mkdir -p ${PATH_VENDORS}

# install go ------------------------------------------------------------------------------
log "installing go..."

if ! command -v "${PATH_GO}/bin/go" >/dev/null 2>&1; then
    GO_VERSION_OLD="none"
else
    GO_VERSION_OLD=`${PATH_GO}/bin/go version | { read _ _ v _; echo ${v#go}; }`
fi

if [[ ${GO_VERSION_OLD} != ${GO_VERSION} ]]; then
    rm -rf ${PATH_GO}
    [[ ! -f go$GO_VERSION.$SYSTEM_OS-$SYSTEM_ARCH.tar.gz ]] &&
        wget https://dl.google.com/go/go$GO_VERSION.$SYSTEM_OS-$SYSTEM_ARCH.tar.gz
    [[ ! -f go$GO_VERSION.$SYSTEM_OS-$SYSTEM_ARCH.tar.gz ]] &&
        die "[install_vendors.sh]: go$GO_VERSION.$SYSTEM_OS-$SYSTEM_ARCH.tar.gz was not found. Check wget URL."

    tar -C ${PATH_VENDORS} -xzvf go$GO_VERSION.$SYSTEM_OS-$SYSTEM_ARCH.tar.gz 
    rm go$GO_VERSION.$SYSTEM_OS-$SYSTEM_ARCH.tar.gz

    if [[ $PATH != *"${PATH_GO}/bin"* ]]; then
        if ! grep -Fxq "export PATH=\$PATH:${PATH_GO}/bin" ~/.bashrc; then
            echo "export PATH=\$PATH:${PATH_GO}/bin" >> ~/.bashrc
        fi
        eval "$(cat ~/.bashrc | tail -n 1)"
    fi
else
    log "go ${GO_VERSION} is already installed."
fi

# install singularity ---------------------------------------------------------------------
log "installing singularity..."

if ! command -v "${PATH_SINGULARITY}/bin/singularity" >/dev/null 2>&1; then
    SINGULARITY_VERSION_OLD=""
else
    SINGULARITY_VERSION_OLD=$(cat ${PATH_SINGULARITY}/VERSION)
fi

if [[ ${SINGULARITY_VERSION_OLD} != ${SINGULARITY_VERSION} ]]; then
    rm -rf ${PATH_SINGULARITY}	
    [[ ! -f singularity-ce-${SINGULARITY_VERSION}.tar.gz ]] && 
        wget https://github.com/sylabs/singularity/releases/download/v${SINGULARITY_VERSION}/singularity-ce-${SINGULARITY_VERSION}.tar.gz
    [[ ! -f singularity-ce-${SINGULARITY_VERSION}.tar.gz ]] &&
        die "[install_vendors.sh]: singularity-ce-${SINGULARITY_VERSION}.tar.gz was not found. Check wget URL."

    tar -xzf singularity-ce-${SINGULARITY_VERSION}.tar.gz
    cd singularity-ce-${SINGULARITY_VERSION}
    log "configuring singularity... please wait, it may take a few minutes..."
    ./mconfig --prefix=${PATH_SINGULARITY} && make -C ./builddir && make -C ./builddir install
    cd ..
    rm singularity-ce-${SINGULARITY_VERSION}.tar.gz
    rm -r singularity-ce-${SINGULARITY_VERSION}
    echo "${SINGULARITY_VERSION}" >> ${PATH_SINGULARITY}/VERSION

    if ! command -v "${PATH_SINGULARITY}/bin/singularity" >/dev/null 2>&1; then
        die "[install_vendors.sh]: singularity was not installed. Please contact us."
    else
        log "singularity succesfully installed..."
    fi

else
    log "singularity ${SINGULARITY_VERSION} is already installed."
fi


#install mambaforge ---------------------------------------------------------------------
log "installing mambaforge..."

if ! command -v "${PATH_MAMBAFORGE}/bin/conda" >/dev/null 2>&1; then
    MAMBAFORGE_VERSION_OLD=""
else
    MAMBAFORGE_VERSION_OLD=$(cat ${PATH_MAMBAFORGE}/VERSION)
fi

if [[ ${MAMBAFORGE_VERSION_OLD} != ${MAMBAFORGE_VERSION} ]]; then
    rm -rf ${PATH_MAMBAFORGE}
    [[ ! -f Mambaforge-$MAMBAFORGE_VERSION-$SYSTEM_OS-$SYSTEM_HDWR.sh ]] &&
        wget https://github.com/conda-forge/miniforge/releases/download/$MAMBAFORGE_VERSION/Mambaforge-$MAMBAFORGE_VERSION-$SYSTEM_OS-$SYSTEM_HDWR.sh
    [[ ! -f Mambaforge-$MAMBAFORGE_VERSION-$SYSTEM_OS-$SYSTEM_HDWR.sh ]] &&
        die "[install_vendors.sh]: Mambaforge-$MAMBAFORGE_VERSION-$SYSTEM_OS-$SYSTEM_HDWR.sh was not found. Check wget URL."

    mkdir -p ${PATH_VENDORS}
    bash Mambaforge-$MAMBAFORGE_VERSION-$SYSTEM_OS-$SYSTEM_HDWR.sh -b -u -p ${PATH_MAMBAFORGE}
    rm Mambaforge-$MAMBAFORGE_VERSION-$SYSTEM_OS-$SYSTEM_HDWR.sh
    echo "${MAMBAFORGE_VERSION}" >> ${PATH_MAMBAFORGE}/VERSION

    if ! command -v "${PATH_MAMBAFORGE}/bin/conda" >/dev/null 2>&1; then
      die "[install_vendors.sh]: conda was not installed. Please contact us."
    elif ! command -v "${PATH_MAMBAFORGE}/bin/mamba" >/dev/null 2>&1; then
      die "[install_vendors.sh]: mamba was not installed. Please contact us." 
    else
      log "mambaforge succesfully installed..."
    fi

else
    log "mambaforge ${MAMBAFORGE_VERSION} is already installed."
fi

log "carme-vendors successfully installed."
