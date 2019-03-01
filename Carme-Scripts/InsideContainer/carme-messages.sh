#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# simple script to display messages in JupyterLab terminals
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#----------------------------------------------------------------------------------------------------------------------------------- 
SETCOLOR='\033[1;33m'
NOCOLOR='\033[0m'
#-----------------------------------------------------------------------------------------------------------------------------------
CARME_MESSAGE_PATH="/home/.CarmeScripts/Carme-Messages"
for file in "${CARME_MESSAGE_PATH}"/* ; do
				if [[ ! ${file: -1} == "~" ]]; then
        if [[ ! $file == *.txt ]]; then
            source $file
        else
            if [[ $file == ${CARME_MESSAGE_PATH}/99-carme-webfrontend-messages.txt ]]; then
                CARME_MESSAGE=$(<$file)
                printf "${SETCOLOR}${CARME_MESSAGE}${NOCOLOR}\n\n"
            else
                CARME_MESSAGE=$(<$file)
                printf "${CARME_MESSAGE}\n\n"
            fi
        fi
				fi
done
