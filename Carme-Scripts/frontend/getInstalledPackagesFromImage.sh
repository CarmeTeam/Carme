#!/bin/bash
# ----------------------------------------------
# Carme                                         
# ----------------------------------------------
# getInstalledPackagesFromImage.sh - list all installed software in an image
# 
# usage: getInstalledPackagesFromImage PATH_TO_IMAGE OUTPUT_FILE
#                                               
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#                                                   
# Copyright 2019 by Fraunhofer ITWM                 
# License: http://open-carme.org/LICENSE.md         
# Contact: info@open-carme.org                      
# ---------------------------------------------   

singularity exec $1 apt list --installed >> $2
singularity exec $1 conda list  >> $2
singularity exec $1 pip list  >> $2
