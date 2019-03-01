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

    CARME_BASH_STR=".bash_carme_"
    CARME_BASH_LIST=( $(find /home/${NAMES}/.carme -type f -name "*${CARME_BASH_STR}*") )

    CARME_THEIA_TMP_STR="_job_tmp"
    CARME_THEIA_TMP_LIST=( $(find /home/${NAMES}/carme_tmp -type d -name "*${CARME_THEIA_TMP_STR}*") )

    RUNNING_JOB_LIST=( $(squeue --noheader --format=%i --user=$NAMES) )
    for RUNNING_JOB_ID in ${RUNNING_JOB_LIST[*]};do
        BASH_HELPER="/home/"${NAMES}"/.carme/.bash_carme_"$RUNNING_JOB_ID
        CARME_BASH_LIST=("${CARME_BASH_LIST[@]/$BASH_HELPER}")
        BASH_HELPER=""
        
        THEIA_HELPER="/home/"${NAMES}"/carme_tmp/"${RUNNING_JOB_ID}
        CARME_THEIA_TMP_LIST=("${CARME_THEIA_TMP_LIST[@]/$THEIA_HELPER}")
        THEIA_HELPER=""
    done

    for OLDFILES in ${CARME_BASH_LIST[*]};do
        if [ -f $OLDFILES ];then
            rm $OLDFILES
        fi
    done

    for OLDFILES in ${CARME_THEIA_TMP_LIST[*]};do
        if [ -d $OLDFILES ];then
            rm -r $OLDFILES
        fi
    done

    #find and delete job logs that are older than 14 days
    find /home/${NAMES}/.job-log-dir/* -mtime +14 -type f -delete
    find /home/${NAMES}/.job-log-dir/* -mtime +14 -type d -delete 

  fi
done

