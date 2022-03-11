#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Copyright 2022 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
#-----------------------------------------------------------------------------------------------------------------------------------


# build and install gpi ------------------------------------------------------------------------------------------------------------

# install system dependencies
apt install -y libtool


# change dir to install location
cd /opt || exit 200


# clone gpi repo
GPI_VERSION="v1.5.1"
git clone --branch "${GPI_VERSION}" --depth 1 https://github.com/cc-hpc-itwm/GPI-2.git GPI-SRC


# build gpi
GPI_INSTALL_PATH="/opt/GPI"

cd /opt/GPI-SRC || exit 200
./autogen.sh
CC=gcc FC=gfortran CFLAGS="-fPIC" CPPFLAGS="-fPIC" ./configure --with-infiniband --prefix="${GPI_INSTALL_PATH}"
make -j 20
make install
cd || exit 200
rm -r /opt/GPI-SRC


# modify 'gaspi_run' and 'gaspi_cleanup' to match our ssh setup
sed -i 's/GASPI_LAUNCHER="ssh"/GASPI_LAUNCHER="ssh -F ${CARME_SSHDIR}\/ssh_config"/g' "${GPI_INSTALL_PATH}/bin/gaspi_run"
sed -i 's/ssh/ssh -F ${CARME_SSHDIR}\/ssh_config/g' "${GPI_INSTALL_PATH}/bin/gaspi_cleanup"


# create links in `/usr/local'
ln -s "${GPI_INSTALL_PATH}/bin/gaspi_cleanup" /usr/local/bin/gaspi_cleanup
ln -s "${GPI_INSTALL_PATH}/bin/gaspi_logger" /usr/local/bin/gaspi_logger
ln -s "${GPI_INSTALL_PATH}/bin/gaspi_run" /usr/local/bin/gaspi_run
ln -s "${GPI_INSTALL_PATH}/bin/ssh.spawner" /usr/local/bin/ssh.spawner

ln -s "${GPI_INSTALL_PATH}"/include/* /usr/local/include/

mkdir -p /usr/local/lib64
ln -s "${GPI_INSTALL_PATH}"/lib64/* /usr/local/lib64/

rm /usr/local/lib64/pkgconfig
mkdir -p /usr/local/lib64/pkgconfig
ln -s "${GPI_INSTALL_PATH}"/lib64/pkgconfig/* /usr/local/lib64/pkgconfig


# clean up
apt autoremove --purge -y
apt clean
#-----------------------------------------------------------------------------------------------------------------------------------
