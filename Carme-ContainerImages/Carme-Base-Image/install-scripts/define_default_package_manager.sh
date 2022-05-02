#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Copyright 2022 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
#-----------------------------------------------------------------------------------------------------------------------------------


# define default package manager ---------------------------------------------------------------------------------------------------

if [[ "${1}" == "miniconda" ]];then

  # set anaconda as default
  cd /opt || exit 200
  ln -s /opt/miniconda3 /opt/package-manager

elif [[ "${1}" == "mambaforge" ]];then

  # set mambaforge as default
  cd /opt || exit 200
  ln -s /opt/mambaforge /opt/package-manager

fi

#-----------------------------------------------------------------------------------------------------------------------------------
