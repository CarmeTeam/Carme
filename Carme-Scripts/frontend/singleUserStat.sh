#!/bin/bash
# ----------------------------------------------
# Carme                                         
# ----------------------------------------------
# singleUserStat.sh - get slurm stats for user
# 
# usage: singleUserStat USER
#                                               
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#                                                   
# Copyright 2019 by Fraunhofer ITWM                 
# License: http://open-carme.org/LICENSE.md         
# Contact: info@open-carme.org                      
# ---------------------------------------------   

source ../../CarmeConfig

echo $1
sacct -S 2018-01-01  --format=User,elapsed | grep $1 | wc | awk '{print $1}'
sacct -S 2018-01-01  --format=User,elapsed | grep $1 | awk '{print $2}' | tr : \ | dc -f - -e '60o0ddd[+r60*+r60d**+z1<a]dsaxp' 
