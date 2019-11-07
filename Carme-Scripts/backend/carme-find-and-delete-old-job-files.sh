#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to find and delete old files from slurm jobs
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------

for PATHS in /home/*;do
  NAMES=(${PATHS##*/})
  LISTIGNORE="container_store CarmeScripts DATA DEMO KURSE root-back scratch SCRATCH SCRIPTS slurm_tmp Systemback UEBUNGEN zabbix-check"
  if [[ ! $LISTIGNORE =~ (^|[[:space:]])$NAMES($|[[:space:]]) ]];then

    #find and delete job logs that are older than 14 days
				find /home/${NAMES}/.local/share/carme/job-log-dir-$(date +"%Y")/* -mtime +14 -type f -delete
				find /home/${NAMES}/.local/share/carme/job-log-dir-$(date +"%Y")/* -mtime +14 -type d -delete 

  fi
done

