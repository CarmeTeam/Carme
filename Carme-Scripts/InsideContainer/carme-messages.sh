#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# simple script to display messages in terminals
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------


# display messages that are provided by carme --------------------------------------------------------------------------------------
CARME_MESSAGE_PATH="/home/.CarmeScripts/Carme-Messages"
mapfile -t CARME_MESSAGES < <(find "${CARME_MESSAGE_PATH}" -maxdepth 1 -type f)

for MESSAGE in "${CARME_MESSAGES[@]}";do
  if [[ ${MESSAGE} == *".sh" ]]; then
    source "${MESSAGE}"
    echo ""
  elif [[ ${MESSAGE} == *".txt" ]]; then
    CARME_MESSAGE=$(<"${MESSAGE}")
    echo "${CARME_MESSAGE}"
    echo ""
  fi
done
#-----------------------------------------------------------------------------------------------------------------------------------


# display cluster specific messages that are not part of carme ---------------------------------------------------------------------
CARME_LOCAL_MESSAGE_PATH="/home/.CarmeScripts/local-messages"
if [[ -d ${CARME_LOCAL_MESSAGE_PATH} ]];then
  mapfile -t CARME_LOCAL_MESSAGES < <(find "${CARME_LOCAL_MESSAGE_PATH}" -maxdepth 1 -type f)

  for MESSAGE in "${CARME_LOCAL_MESSAGES[@]}";do
    if [[ ${MESSAGE} == *".sh" ]]; then
      source "${MESSAGE}"
      echo ""
    elif [[ ${MESSAGE} == *".txt" ]]; then
      CARME_MESSAGE=$(<"${MESSAGE}")
      echo "${CARME_MESSAGE}"
      echo ""
    fi
  done
fi
#-----------------------------------------------------------------------------------------------------------------------------------
