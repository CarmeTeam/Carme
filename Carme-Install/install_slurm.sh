#!/bin/bash
#-----------------------------------------------------------------------------------------#
#----------------------------------- SLURM installation ----------------------------------#
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

  CARME_USER=$(get_variable CARME_USER ${FILE_START_CONFIG})
  CARME_GROUP=$(get_variable CARME_GROUP ${FILE_START_CONFIG})
  CARME_SLURM=$(get_variable CARME_SLURM ${FILE_START_CONFIG})
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})
  CARME_DB_SLURM_NAME=$(get_variable CARME_DB_SLURM_NAME ${FILE_START_CONFIG})
  CARME_DB_SLURM_USER=$(get_variable CARME_DB_SLURM_USER ${FILE_START_CONFIG})
  CARME_MUNGE_PATH_RUN=$(get_variable CARME_MUNGE_PATH_RUN ${FILE_START_CONFIG})
  CARME_MUNGE_FILE_KEY=$(get_variable CARME_MUNGE_FILE_KEY ${FILE_START_CONFIG})
  CARME_PASSWORD_SLURM=$(get_variable CARME_PASSWORD_SLURM ${FILE_START_CONFIG})
  CARME_SLURM_SLURMD_PORT=$(get_variable CARME_SLURM_SLURMD_PORT ${FILE_START_CONFIG})
  CARME_SLURM_CLUSTER_NAME=$(get_variable CARME_SLURM_CLUSTER_NAME ${FILE_START_CONFIG})
  CARME_SLURM_PARTITION_NAME=$(get_variable CARME_SLURM_PARTITION_NAME ${FILE_START_CONFIG})
  CARME_SLURM_SLURMCTLD_PORT=$(get_variable CARME_SLURM_SLURMCTLD_PORT ${FILE_START_CONFIG})

  [[ -z ${CARME_USER} ]] && die "[install_slurm.sh]: CARME_USER not set."
  [[ -z ${CARME_GROUP} ]] && die "[install_slurm.sh]: CARME_GROUP not set."
  [[ -z ${CARME_SLURM} ]] && die "[install_slurm.sh]: CARME_SLURM not set."
  [[ -z ${CARME_SYSTEM} ]] && die "[install_slurm.sh]: CARME_SYSTEM not set."
  [[ -z ${CARME_NODE_LIST} ]] && die "[install_slurm.sh]: CARME_NODE_LIST not set."
  [[ -z ${CARME_DB_SLURM_NAME} ]] && die "[install_slurm.sh]: CARME_DB_SLURM_NAME not set."
  [[ -z ${CARME_DB_SLURM_USER} ]] && die "[install_slurm.sh]: CARME_DB_SLURM_USER not set."
  [[ -z ${CARME_MUNGE_PATH_RUN} ]] && die "[install_slurm.sh]: CARME_MUNGE_PATH_RUN not set."
  [[ -z ${CARME_MUNGE_FILE_KEY} ]] && die "[install_slurm.sh]: CARME_MUNGE_FILE_KEY not set."
  [[ -z ${CARME_PASSWORD_SLURM} ]] && die "[install_slurm.sh]: CARME_PASSWORD_SLURM not set."
  [[ -z ${CARME_SLURM_SLURMD_PORT} ]] && die "[install_slurm.sh]: CARME_SLURM_SLURMD_PORT not set."
  [[ -z ${CARME_SLURM_CLUSTER_NAME} ]] && die "[install_slurm.sh]: CARME_SLURM_CLUSTER_NAME not set."
  [[ -z ${CARME_SLURM_PARTITION_NAME} ]] && die "[install_slurm.sh]: CARME_SLURM_PARTITION_NAME not set."
  [[ -z ${CARME_SLURM_SLURMCTLD_PORT} ]] && die "[install_slurm.sh]: CARME_SLURM_SLURMCTLD_PORT not set."

else
  die "[install_slurm.sh]: ${FILE_START_CONFIG} not found."
fi

# installation / configuration starts -----------------------------------------------------
if [[ ${CARME_SLURM} == "yes" ]]; then
  log "starting slurm installation..."
else
  log "starting slurm configuration..."
fi

# check system ----------------------------------------------------------------------------
if ! [[ ${CARME_SYSTEM} == "single" || ${CARME_SYSTEM} == "multi" ]]; then
  die "[install_slurm.sh]: CARME_SYSTEM in CarmeConfig.start was not set properly. It must be \`single\` or \`multi\`."
fi
if ! [[ ${CARME_SLURM} == "yes" || ${CARME_SLURM} == "no" ]]; then
  die "[install_slurm.sh]: CARME_SLURM in CarmeConfig.start was not set properly. It must be \`yes\` or \`no\`."
fi

# install packages ------------------------------------------------------------------------
if [[ ${CARME_SLURM} == "yes" ]]; then
  log "installing packages..."

  # single device
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    MY_PKGS=(slurmctld slurmd slurmdbd libpmix-dev)
    # libpmix-dev is required 
    # https://linux.debian.bugs.dist.narkive.com/wxMHknxm/bug-954272-slurmd-slurm-not-working-with-openmpi
    MISSING_PKGS=""
    for MY_PKG in ${MY_PKGS[@]}; do
      if [[ $(installed $MY_PKG "single") == "not installed" ]]; then
        MISSING_PKGS+=" $MY_PKG"
      fi
    done
    if [ ! -z "$MISSING_PKGS" ]; then
      dpkg --configure -a
      apt install $MISSING_PKGS -y
    fi
    for MY_PKG in ${MY_PKGS[@]}; do
      if [[ $(installed $MY_PKG "single") == "not installed" ]]; then
        die "[install_slurm.sh]: $MY_PKG was not installed. Please try again."
      fi
    done

  # cluster
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    # cluster head node 
    HEAD_NODE_PKGS=(slurmctld slurmdbd libpmix-dev)
    MISSING_HEAD_NODE_PKGS=""
    for HEAD_NODE_PKG in ${HEAD_NODE_PKGS[@]}; do
      if [[ $(installed $HEAD_NODE_PKG "single") == "not installed" ]]; then
        MISSING_HEAD_NODE_PKGS+=" $HEAD_NODE_PKG"
      fi
    done
    if [ ! -z "$MISSING_HEAD_NODE_PKGS" ]; then
      dpkg --configure -a
      apt install $MISSING_HEAD_NODE_PKGS -y
    fi
    for HEAD_NODE_PKG in ${HEAD_NODE_PKGS[@]}; do
      if [[ $(installed $HEAD_NODE_PKG "single") == "not installed" ]]; then
        die "[install_slurm.sh]: $HEAD_NODE_PKG was not installed. Please try again."
      fi
    done
    # cluster compute nodes
    COMPUTE_NODE_PKGS=(slurmd slurm-client libpmix-dev)
    MISSING_COMPUTE_NODE_PKGS=""
    for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      for COMPUTE_NODE_PKG in ${COMPUTE_NODE_PKGS[@]}; do
        if [[ $(installed $COMPUTE_NODE_PKG $COMPUTE_NODE) == "not installed" ]]; then
          MISSING_COMPUTE_NODE_PKGS+=" $COMPUTE_NODE_PKG"
        fi
      done
      if [ ! -z "$MISSING_COMPUTE_NODE_PKGS" ]; then
	ssh -t $COMPUTE_NODE "dpkg --configure -a"
        ssh -t $COMPUTE_NODE "apt install $MISSING_COMPUTE_NODE_PKGS -y"
      fi
      for COMPUTE_NODE_PKG in ${COMPUTE_NODE_PKGS[@]}; do
        if [[ $(installed $COMPUTE_NODE_PKG $COMPUTE_NODE) == "not installed" ]]; then
          die "[install_slurm.sh]: $COMPUTE_NODE_PKG in node $COMPUTE_NODE was not installed. Please try again."
        fi
      done
    done
  fi

fi

# install/configure variables -------------------------------------------------------------
PATH_ETC_SLURM=$(dpkg -L slurmctld | grep '/etc/slurm' | head -n1)
PATH_ETC_MUNGE=$(dirname ${CARME_MUNGE_FILE_KEY})
PATH_RUN_MUNGE=${CARME_MUNGE_PATH_RUN}

FILE_CARME_GPU_CONFIG=${PATH_ETC_SLURM}/carme-gpu.conf
FILE_SLURMDBD_CONFIG=${PATH_ETC_SLURM}/slurmdbd.conf
FILE_SLURM_CONFIG=${PATH_ETC_SLURM}/slurm.conf
FILE_GRES_CONFIG=${PATH_ETC_SLURM}/gres.conf
FILE_MUNGE_KEY=${CARME_MUNGE_FILE_KEY}

PORT_SLURMCTLD=${CARME_SLURM_SLURMCTLD_PORT}
PORT_SLURMD=${CARME_SLURM_SLURMD_PORT}

if [[ ${CARME_SLURM} == "yes" ]]; then

  PATH_VAR_LOG_SLURM_SLURMD=$(dpkg -L slurmctld | grep '/var/log/slurm' | head -n1)
  PATH_VAR_LOG_SLURM_SLURMDBD=$(dpkg -L slurmctld | grep '/var/log/slurm' | head -n1)
  PATH_VAR_LOG_SLURM_SLURMCTLD=$(dpkg -L slurmctld | grep '/var/log/slurm' | head -n1)

  PATH_VAR_LIB_SLURM_SLURMD=$(dpkg -L slurmctld | grep '/var/lib/slurm' | head -n1)/slurmd
  PATH_VAR_LIB_SLURM_SLURMCTLD=$(dpkg -L slurmctld | grep '/var/lib/slurm' | head -n1)/slurmctld

  PATH_RUN_SLURM_SLURMD=/var/run
  PATH_RUN_SLURM_SLURMDBD=/var/run
  PATH_RUN_SLURM_SLURMCTLD=/var/run

elif [[ ${CARME_SLURM} == "no" ]]; then

  PATH_VAR_LOG_SLURM_SLURMD=$(dirname $(get_variable SlurmdLogFile ${FILE_SLURM_CONFIG}))
  PATH_VAR_LOG_SLURM_SLURMDBD=$(dirname $(get_variable LogFile ${FILE_SLURMDBD_CONFIG}))
  PATH_VAR_LOG_SLURM_SLURMCTLD=$(dirname $(get_variable SlurmctldLogFile ${FILE_SLURM_CONFIG}))
  
  PATH_VAR_LIB_SLURM_SLURMD=$(get_variable SlurmdSpoolDir ${FILE_SLURM_CONFIG})
  PATH_VAR_LIB_SLURM_SLURMCTLD=$(get_variable StateSaveLocation ${FILE_SLURM_CONFIG})

  PATH_RUN_SLURM_SLURMD=$(dirname $(get_variable SlurmdPidFile ${FILE_SLURM_CONFIG}))
  PATH_RUN_SLURM_SLURMDBD=$(dirname $(get_variable PidFile ${FILE_SLURMDBD_CONFIG}))
  PATH_RUN_SLURM_SLURMCTLD=$(dirname $(get_variable SlurmctldPidFile ${FILE_SLURM_CONFIG}))  

fi

# check paths -----------------------------------------------------------------------------
log "checking slurm paths..."

# single device
if [[ ${CARME_SYSTEM} == "single" ]]; then
  MY_PATHS=($PATH_VAR_LIB_SLURM_SLURMCTLD $PATH_VAR_LIB_SLURM_SLURMD $PATH_VAR_LOG_SLURM_SLURMCTLD $PATH_VAR_LOG_SLURM_SLURMDBD $PATH_VAR_LOG_SLURM_SLURMD $PATH_ETC_SLURM $PATH_ETC_MUNGE $PATH_RUN_MUNGE $PATH_RUN_SLURM_SLURMCTLD $PATH_RUN_SLURM_SLURMDBD $PATH_RUN_SLURM_SLURMD)
  for MY_PATH in ${MY_PATHS[@]}; do
    if ! [ -d "$MY_PATH" ]; then
      die "[install_slurm.sh]: $MY_PATH does not exist. Your current slurm installation is not set in default paths. Please contact us."
    fi
  done

# cluster
elif [[ ${CARME_SYSTEM} == "multi" ]]; then
  MY_HEAD_NODE_PATHS=($PATH_VAR_LIB_SLURM_SLURMCTLD $PATH_VAR_LOG_SLURM_SLURMCTLD $PATH_VAR_LOG_SLURM_SLURMDBD $PATH_ETC_SLURM $PATH_ETC_MUNGE $PATH_RUN_MUNGE $PATH_RUN_SLURM_SLURMCTLD $PATH_RUN_SLURM_SLURMDBD)
  MY_COMPUTE_NODE_PATHS=($PATH_VAR_LIB_SLURM_SLURMD $PATH_VAR_LOG_SLURM_SLURMD $PATH_ETC_SLURM $PATH_ETC_MUNGE $PATH_RUN_MUNGE $PATH_RUN_SLURM_SLURMD)
  for MY_PATH in ${MY_HEAD_NODE_PATHS[@]}; do
    if ! [ -d $MY_PATH ]; then
      die "[install_slurm.sh]: $MY_PATH does not exist in the head-node. Your current slurm installation is not set in default paths. Please contact us."
    fi
  done
  log "slurm paths in head-node exist."
  for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
    for MY_PATH in ${MY_COMPUTE_NODE_PATHS[@]}; do
      if ssh $COMPUTE_NODE "! [ -d $MY_PATH ]"
      then
        die "[install_slurm.sh]: $MY_PATH does not exist in the compute-node $COMPUTE_NODE. Your current slurm installation is not set in default paths. Please contact us."
      fi
    done
    log "slurm paths in compute-node ${COMPUTE_NODE} exist."
  done
fi

# check ports -----------------------------------------------------------------------------
if [[ ${CARME_SLURM} == "yes" ]]; then
  log "checking ports..."

  # single device
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    CHECK_PORTS_MESSAGE1="Ports ${PORT_SLURMCTLD} and ${PORT_SLURMD} are not free. \
To proceed, the processes using ports ${PORT_SLURMCTLD} and ${PORT_SLURMD} will be killed. \
Do you want to continue? [y/N]"
    CHECK_PORTS_MESSAGE2="Port ${PORT_SLURMCTLD} is not free. \
To proceed, the process using port ${PORT_SLURMCTLD} will be killed. \
Do you want to continue? [y/N]"
    CHECK_PORTS_MESSAGE3="Port ${PORT_SLURMD} is not free. \
To proceed, the process using port ${PORT_SLURMD} will be killed. \
Do you want to continue? [y/N]"

    if ! [[ -z $(lsof -i:${PORT_SLURMCTLD}) ]] && ! [[ -z $(lsof -i:${PORT_SLURMD}) ]]; then
      read -rp "${CHECK_PORTS_MESSAGE1} " REPLY
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        kill $(lsof -t -i:${PORT_SLURMCTLD})
        kill $(lsof -t -i:${PORT_SLURMD})
      else
        die "[install_slurm.sh]: Installation stopped. Ports are not free."
      fi
    fi
    if ! [[ -z $(lsof -i:${PORT_SLURMCTLD}) ]] && [[ -z $(lsof -i:${PORT_SLURMD}) ]]; then
      read -rp "${CHECK_PORTS_MESSAGE2} " REPLY
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        kill $(lsof -t -i:${PORT_SLURMCTLD})
      else
        die "[install_slurm.sh]: Installation stopped. Port is not free."
      fi
    fi
    if ! [[ -z $(lsof -i:${PORT_SLURMD}) ]] && [[ -z $(lsof -i:${PORT_SLURMCTLD}) ]]; then
      read -rp "${CHECK_PORTS_MESSAGE3} " REPLY
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        kill $(lsof -t -i:${PORT_SLURMD})
      else
        die "[install_slurm.sh]: Installation stopped. Port is not free."
      fi
    fi

    if ! [[ -z $(lsof -i:${PORT_SLURMCTLD}) ]]; then
      die "[install_slurm.sh]: The process using port ${PORT_SLURMCTLD} was not killed."
    fi
    if ! [[ -z $(lsof -i:${PORT_SLURMD}) ]]; then
      die "[install_slurm.sh]: The process using port ${PORT_SLURMD} was not killed."
    fi

  # cluster  
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    CHECK_PORTS_MESSAGE4="Port ${PORT_SLURMCTLD} in head-node is not free. \
To proceed, the process using port ${PORT_SLURMCTLD} will be killed. \
Do you want to continue? [y/N]"
    if ! [[ -z $(lsof -i:${PORT_SLURMCTLD}) ]]; then
      read -rp "${CHECK_PORTS_MESSAGE4} " REPLY
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        kill $(lsof -t -i:${PORT_SLURMCTLD})
      else
        die "[install_slurm.sh]: Installation stopped. Port in head-node is not free."
      fi
    fi
    for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      CHECK_PORTS_MESSAGE5="Port ${PORT_SLURMD} in compute-node ${COMPUTE_NODE} is not free. \
To proceed, the process using port ${PORT_SLURMD} will be killed. \
Do you want to continue? [y/N]"
      MY_PORT=$(ssh ${COMPUTE_NODE} echo '$(lsof -i:'${PORT_SLURMD}')')
       if ! [[ -z $MY_PORT ]]; then
         read -rp "${CHECK_PORTS_MESSAGE5} " REPLY
	 if [[ $REPLY =~ ^[Yy]$ ]]; then
           ssh ${COMPUTE_NODE} 'kill $(lsof -t -i:'${PORT_SLURMD}')'
         else
           die "[install_slurm.sh]: Installation stopped. Port is not free."
         fi
       fi
    done

    if ! [[ -z $(lsof -i:${PORT_SLURMCTLD}) ]]; then
      die "[install_slurm.sh]: The process using port ${PORT_SLURMCTLD} was not killed in the head-node."
    fi
    for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      MY_PORT=$(ssh ${COMPUTE_NODE} echo '$(lsof -i:'${PORT_SLURMD}')')
      if ! [[ -z $MY_PORT ]]; then
        die "[install_slurm.sh]: The process using port ${PORT_SLURMD} was not killed in the compute-node ${COMPUTE_NODE}."
      fi
    done

  fi

fi

# set slurm.conf, gres.conf, and carme-gpu.conf ---------------------------------------------
if [[ ${CARME_SLURM} == "yes" ]]; then
  log "setting slurm.conf..."

  rm -f ${FILE_GRES_CONFIG}
  rm -f ${FILE_SLURM_CONFIG}
  rm -f ${FILE_CARME_GPU_CONFIG}
  
  touch ${FILE_GRES_CONFIG}
  touch ${FILE_SLURM_CONFIG}
  touch ${FILE_CARME_GPU_CONFIG}

  # AccountingStoreFlags or AccountingStoreJobComment variable
  SLURM_ACCOUNTING_SETTINGS="AccountingStoreFlags=job_comment"
  SLURM_VERSION=$(slurmctld -V | cut -d' ' -f2 | cut -d. -f1)
  if [ $SLURM_VERSION -le 20 ]; then
    SLURM_ACCOUNTING_SETTINGS="AccountingStoreJobComment=YES"
  fi
 
  # SlurmctldHost variable
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    SLURM_CONTROLLER_HOST="localhost"
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    SLURM_CONTROLLER_HOST=$(hostname -s | awk '{print $1}')
  fi

  cat << EOF >> ${FILE_SLURM_CONFIG}
# slurm.conf file 
#
# GENERAL ---------------------------------------------------------------------------------
ClusterName=${CARME_SLURM_CLUSTER_NAME}
SlurmctldHost=${SLURM_CONTROLLER_HOST}
#
# PROLOG AND EPILOG -----------------------------------------------------------------------
#Prolog=# to be set with install_script.sh
#PrologSlurmctld=# to be set with install_script.sh
#Epilog=# to be set with install_Script.sh
#EpilogSlurmctld=# to be set with install_Script.sh
#
# SERVICES --------------------------------------------------------------------------------
SlurmUser=slurm
SlurmctldPort=${PORT_SLURMCTLD}
SlurmdPort=${PORT_SLURMD}
SlurmctldPidFile=${PATH_RUN_SLURM_SLURMCTLD}/slurmctld.pid
SlurmdPidFile=${PATH_RUN_SLURM_SLURMD}/slurmd.pid
StateSaveLocation=${PATH_VAR_LIB_SLURM_SLURMCTLD}
SlurmdSpoolDir=${PATH_VAR_LIB_SLURM_SLURMD}
SwitchType=switch/none
TaskPlugin=task/none
ProctrackType=proctrack/linuxproc
ReturnToService=2
MpiDefault=none
#
# TIMERS ----------------------------------------------------------------------------------
InactiveLimit=7200
KillWait=30
MinJobAge=300
SlurmctldTimeout=120
SlurmdTimeout=300
Waittime=0
#
# SCHEDULING ------------------------------------------------------------------------------
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_CPU_Memory
#
# ACCOUNTING ------------------------------------------------------------------------------
AccountingStorageEnforce=associations,limits,safe
AccountingStorageType=accounting_storage/slurmdbd
${SLURM_ACCOUNTING_SETTINGS}
#
# JOB -------------------------------------------------------------------------------------
JobRequeue=0
JobCompType=jobcomp/none
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/linux
#
# LOGGING ---------------------------------------------------------------------------------
SlurmctldDebug=info
SlurmctldLogFile=${PATH_VAR_LOG_SLURM_SLURMCTLD}/slurmctld.log
SlurmdDebug=info
SlurmdLogFile=${PATH_VAR_LOG_SLURM_SLURMD}/slurmd.log
#
# COMPUTE NODE ----------------------------------------------------------------------------
#
# PARTITION -------------------------------------------------------------------------------
PartitionName=${CARME_SLURM_PARTITION_NAME} Nodes=ALL Default=YES MaxTime=4320 State=UP
EOF

  # set single device ------------------------------------------ 
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    which nvidia-smi && nvidia-smi --query-gpu=gpu_name --format=csv >/dev/null 2>&1
    
    # set single device as cpu or gpu system
    if [ $? -eq 0 ]; then
      REPLY=""
      CHECK_DEVICE_MESSAGE=$"
Do you want your single device to be a CPU or GPU node (both are not allowed)? 
Type \`cpu\` or \`gpu\`, respectively. [cpu/gpu]:"
      while ! [[ ${REPLY} == "cpu" || ${REPLY} == "gpu" ]] 
      do
        read -rp "${CHECK_DEVICE_MESSAGE} " REPLY
        if [[ ${REPLY} == "cpu" ]]; then
          SYSTEM_DEVICE="cpu"
        elif [[ ${REPLY} == "gpu" ]]; then
          SYSTEM_DEVICE="gpu"
        else
          CHECK_DEVICE_MESSAGE=$'You did not type `cpu` or `gpu`. Please try again [cpu/gpu]:'
        fi
      done	
    else
      SYSTEM_DEVICE="cpu"
    fi
 
    # set single device parameters
    REAL_MEMORY=$(grep "^MemTotal:" /proc/meminfo | awk '{print int($2/1024)}')
    REAL_MEMORY_SMALLER=$(($REAL_MEMORY - 200))
    SLURMD_C=$(slurmd -C 2>/dev/null || echo no)
    if [[ ${SLURMD_C} == "no" ]]; then
      die "[install_slurm.sh]: slurmd -C does not exist in your system"
    elif [[ -z "${SLURMD_C}" ]]; then
      die "[install_slurm.sh]: slurmd -C info is empty in your system."
    else
      NODE_HOSTNAME=$(hostname -s | awk '{print $1}')
      NODE_INFO=${SLURMD_C%UpTime*}
      NODE_INFO_REAL=$(echo $NODE_INFO | sed "s/$REAL_MEMORY/$REAL_MEMORY_SMALLER/")
      NODE_INFO_REAL=$(echo "${NODE_INFO_REAL}" | sed 's/^.*CPU/CPU/')
      if [[ ${SYSTEM_DEVICE} == "cpu" ]]; then
        COMPUTE_NODE_INFO="NodeName=${NODE_HOSTNAME} ${NODE_INFO_REAL} state=UNKNOWN feature=carme"
      elif [[ ${SYSTEM_DEVICE} == "gpu" ]]; then
	sed -i '/# ACCOUNTING --------/a AccountingStorageTRES=gres/gpu' ${FILE_SLURM_CONFIG}
        sed -i '/# ACCOUNTING --------/a GresTypes=gpu' ${FILE_SLURM_CONFIG}
        GPU_NUM=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
        GPU_LOOP=$(($GPU_NUM-1))

	# set single device as homogeneous GPU system. Heterogeneous GPU system is not implemented (all GPUs must be the same).
        for i in $(seq 0 $GPU_LOOP); do
          if [[ ${i} == 0 ]]; then
            GPU_NAME=$(nvidia-smi -i $i --query-gpu=name --format=csv,noheader)
          else
            GPU_NAME_PLUS=$(nvidia-smi -i $i --query-gpu=name --format=csv,noheader)
            if [[ ${GPU_NAME_PLUS} != ${GPU_NAME} ]]; then
              die "[install_slurm.sh]: GPU names are not the same. \`install_slurm.sh\` requires homogeneous GPUs. Please, contact us if this is not your case."
            fi
          fi
        done
        
        # set single device carme-gpu.conf  
	if grep -q -i "^${GPU_NAME}" "${FILE_CARME_GPU_CONFIG}"; then
          GPU_SHORT=$(get_variable ${GPU_NAME} ${FILE_CARME_GPU_CONFIG})
          [[ -z ${GPU_SHORT} ]] && die "[install_slurm.sh]: ${GPU_NAME} short name was not set in ${FILE_CARME_GPU_CONFIG}. Add a proper short name."
        else
          REPLY=""
          SHORT_STOP=""
          CHECK_DEVICE_NAME_MESSAGE=$"
${GPU_NAME} exists in your system. 
Type a short name to identify this GPU. [short name]: "
          while ! [[ ${SHORT_STOP} == "yes" ]]
          do
            read -rp "${CHECK_DEVICE_NAME_MESSAGE} " REPLY
            if [[ $REPLY =~ ^[0-9a-zA-Z]+$ ]]; then
              SHORT_STOP="yes"
              GPU_SHORT="$REPLY"
	      GPU_SHORT=$(echo "${GPU_SHORT}" | tr '[:upper:]' '[:lower:]')
              echo "${GPU_NAME}=${GPU_SHORT}" >> "${FILE_CARME_GPU_CONFIG}"
            else
              CHECK_DEVICE_NAME_MESSAGE=$"Sorry, neither special characters nor blank spaces are allowed. Please, try again. [short name]: "
            fi
          done
        fi

	# set single device gres.conf
	COMPUTE_NODE_INFO="NodeName=${NODE_HOSTNAME} Gres=gpu:${GPU_SHORT}:${GPU_NUM} ${NODE_INFO_REAL} state=UNKNOWN feature=carme"
        for i in $(seq 0 $GPU_LOOP); do
          echo "NodeName=${NODE_HOSTNAME} Name=gpu Type=${GPU_SHORT} File=/dev/nvidia${i}" >> "${FILE_GRES_CONFIG}"
        done

      fi
      sed -i "/# COMPUTE NODE --------/a ${COMPUTE_NODE_INFO}" ${FILE_SLURM_CONFIG}
    fi

  # set cluster ------------------------------------------------
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    
    for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      ssh ${COMPUTE_NODE} 'nvidia-smi --query-gpu=gpu_name --format=csv >/dev/null 2>&1'

      # set cluster compute node as cpu or gpu
      if [ $? -eq 0 ]; then
        REPLY=""
        CHECK_DEVICE_MESSAGE=$"
Do you want compute node ${COMPUTE_NODE} to be a CPU or GPU node (both are not allowed)?
Type \`cpu\` or \`gpu\`, respectively. [cpu/gpu]:"
        while ! [[ ${REPLY} == "cpu" || ${REPLY} == "gpu" ]] 
        do
          read -rp "${CHECK_DEVICE_MESSAGE} " REPLY
          if [[ ${REPLY} == "cpu" ]]; then
            SYSTEM_DEVICE="cpu"
          elif [[ ${REPLY} == "gpu" ]]; then
            SYSTEM_DEVICE="gpu"
          else
            CHECK_DEVICE_MESSAGE=$'You did not type `cpu` or `gpu`. Please try again [cpu/gpu]:'
          fi
        done
      else
        SYSTEM_DEVICE="cpu"
      fi

      # set cluster parameters
      REAL_MEMORY=$(ssh ${COMPUTE_NODE} 'grep "^MemTotal:" /proc/meminfo' | awk '{print int($2/1024)}')
      REAL_MEMORY_SMALLER=$(($REAL_MEMORY - 200))
      SLURMD_C=$(ssh ${COMPUTE_NODE} 'slurmd -C 2>/dev/null || echo no')
      if [[ ${SLURMD_C} == "no" ]]; then
        die "[install_slurm.sh]: slurmd -C does not exist in compute-node ${COMPUTE_NODE}."
      elif [[ -z "${SLURMD_C}" ]]; then
        die "[install_slurm.sh]: slurmd -C info is empty in compute-node ${COMPUTE_NODE}."
      else
        NODE_HOSTNAME=${COMPUTE_NODE}
        NODE_INFO=${SLURMD_C%UpTime*}
        NODE_INFO_REAL=$(echo $NODE_INFO | sed "s/$REAL_MEMORY/$REAL_MEMORY_SMALLER/")
        NODE_INFO_REAL=$(echo "${NODE_INFO_REAL}" | sed 's/^.*CPU/CPU/')
	if [[ ${SYSTEM_DEVICE} == "cpu" ]]; then
          COMPUTE_NODE_INFO="NodeName=${NODE_HOSTNAME} ${NODE_INFO_REAL} state=UNKNOWN feature=carme"
	elif [[ ${SYSTEM_DEVICE} == "gpu" ]]; then
          if ! grep -q -i "^AccountingStorageTRES=gres/gpu" "${FILE_SLURM_CONFIG}"; then
            sed -i '/# ACCOUNTING --------/a AccountingStorageTRES=gres/gpu' ${FILE_SLURM_CONFIG}
	  fi
	  if ! grep -q -i "^GresTypes=gpu" "${FILE_SLURM_CONFIG}"; then
            sed -i '/# ACCOUNTING --------/a GresTypes=gpu' ${FILE_SLURM_CONFIG}
	  fi
          GPU_NUM=$(ssh ${COMPUTE_NODE} 'nvidia-smi --query-gpu=name --format=csv,noheader | wc -l')
          GPU_LOOP=$(($GPU_NUM-1))

	  # set cluster compute node as homogeneous GPU node. Heterogeneous GPU node is not implemented (all GPUs must be the same).
          for i in $(seq 0 $GPU_LOOP); do
            if [[ ${i} == 0 ]]; then
              GPU_NAME=$(ssh ${COMPUTE_NODE} "nvidia-smi -i $i --query-gpu=name --format=csv,noheader")
	    else
              GPU_NAME_PLUS=$(ssh ${COMPUTE_NODE} "nvidia-smi -i $i --query-gpu=name --format=csv,noheader")
              if [[ ${GPU_NAME_PLUS} != ${GPU_NAME} ]]; then
	        die "[install_slurm.sh]: GPUs in compute node ${COMPUTE_NODE} are not the same. \`install_slurm.sh\` requires a homogeneous GPU node. Please, contact us if this is not your case."
	      fi
            fi
          done

	  # set cluster carme-gpu.conf
          if grep -q -i "^${GPU_NAME}" "${FILE_CARME_GPU_CONFIG}"; then
	    GPU_SHORT=$(get_variable ${GPU_NAME} ${FILE_CARME_GPU_CONFIG})
	    [[ -z ${GPU_SHORT} ]] && die "[install_slurm.sh]: ${GPU_NAME} short name was not set in ${FILE_CARME_GPU_CONFIG}. Add a proper short name."  
	  else
            REPLY=""
	    SHORT_STOP=""
	    CHECK_DEVICE_NAME_MESSAGE=$"
${GPU_NAME} exists in your system. 
Type a short name to identify this GPU. [short name]: "
            while ! [[ ${SHORT_STOP} == "yes" ]]
	    do
	      read -rp "${CHECK_DEVICE_NAME_MESSAGE} " REPLY
	      if [[ $REPLY =~ ^[0-9a-zA-Z]+$ ]]; then
		GPU_SHORT="$REPLY"
		GPU_SHORT=$(echo "${GPU_SHORT}" | tr '[:upper:]' '[:lower:]')
		if grep -q -i "=${GPU_SHORT}" "${FILE_CARME_GPU_CONFIG}"; then
		  CHECK_DEVICE_NAME_MESSAGE=$"Sorry, \`${GPU_SHORT}\` is already taken. Please, choose a different name. [short name]: "
	        else
		  SHORT_STOP="yes"
		  echo "${GPU_NAME}=${GPU_SHORT}" >> "${FILE_CARME_GPU_CONFIG}"
		fi
	      else
    	        CHECK_DEVICE_NAME_MESSAGE=$"Sorry, neither special characters nor blank spaces are allowed. Please, try again. [short name]: "    
      	      fi
	    done
	  fi

	  # set cluster gres.conf
          COMPUTE_NODE_INFO="NodeName=${NODE_HOSTNAME} Gres=gpu:${GPU_SHORT}:${GPU_NUM} ${NODE_INFO_REAL} state=UNKNOWN feature=carme"
	  for i in $(seq 0 $GPU_LOOP); do 
	    echo "NodeName=${COMPUTE_NODE} Name=gpu Type=${GPU_SHORT} File=/dev/nvidia${i}" >> "${FILE_GRES_CONFIG}"
          done
	fi
        sed -i "/# COMPUTE NODE --------/a ${COMPUTE_NODE_INFO}" ${FILE_SLURM_CONFIG}
      fi
    done        
  fi

  chmod 644 "${FILE_SLURM_CONFIG}" || die "[install_slurm.sh]: cannot change file permissions of ${FILE_SLURM_CONFIG}."

  # set slurmdbd.conf ---------------------------------------------------------------------
  log "setting slurmdbd.conf..."

  rm -f ${FILE_SLURMDBD_CONFIG}
  touch ${FILE_SLURMDBD_CONFIG}

  cat << EOF >> ${FILE_SLURMDBD_CONFIG}
# slurmdbd.conf file
#
# -------------------------------------------
ArchiveEvents=yes
ArchiveJobs=yes
ArchiveSteps=no
ArchiveSuspend=no
AuthInfo=${PATH_RUN_MUNGE}/munge.socket.2
AuthType=auth/munge
DbdHost=localhost
DbdAddr=localhost
DebugLevel=7
PurgeEventAfter=1month
PurgeJobAfter=12month
PurgeStepAfter=1month
PurgeSuspendAfter=1month
LogFile=${PATH_VAR_LOG_SLURM_SLURMDBD}/slurmdbd.log
PidFile=${PATH_RUN_SLURM_SLURMDBD}/slurmdbd.pid
SlurmUser=${CARME_DB_SLURM_USER}
StoragePass=${CARME_PASSWORD_SLURM}
StorageType=accounting_storage/mysql
StorageUser=${CARME_DB_SLURM_USER}
# --------------------------------------------
EOF

  chmod 600 "${FILE_SLURMDBD_CONFIG}" || die "[install_slurm.sh]: cannot change file permissions of ${FILE_SLURMDBD_CONFIG}."
  chown ${CARME_DB_SLURM_USER}:${CARME_DB_SLURM_USER} "${FILE_SLURMDBD_CONFIG}"

elif [[ ${CARME_SLURM} == "no" ]]; then
  log "checking slurm services..."

  # check services are running in single device
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    systemctl is-active --quiet munge || die "[install_slurm.sh]: munge.service is not running."
    systemctl is-active --quiet slurmd || die "[install_slurm.sh]: slurmd.service is not running."
    systemctl is-active --quiet slurmdbd || die "[install_slurm.sh]: slurmdbd.service is not running."
    systemctl is-active --quiet slurmctld || die "[install_slurm.sh]: slurmctld.service is not running."  
    log "slurm services are running."

  # check services are running in cluster  
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    systemctl is-active --quiet munge || die "[install_slurm.sh]: munge.service in head-node is not running."
    systemctl is-active --quiet slurmdbd || die "[install_slurm.sh]: slurmdbd.service in head-node is not running."
    systemctl is-active --quiet slurmctld || die "[install_slurm.sh]: slurmctld.service in head-node is not running."
    log "slurm services in head-node are running."
    
    for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      MUNGE_STATUS=$(ssh ${COMPUTE_NODE} 'systemctl is-active --quiet munge && echo "running" || echo "not running"')
      SLURMD_STATUS=$(ssh ${COMPUTE_NODE} 'systemctl is-active --quiet slurmd && echo "running" || echo "not running"')
      [[ $MUNGE_STATUS == "running" ]] || die "[install_slurm.sh]: munge.service in compute-node ${COMPUTE_NODE} is not running."
      [[ $SLURMD_STATUS == "running" ]] || die "[install_slurm.sh]: slurmd.service in compute-node ${COMPUTE_NODE} is not running."
      log "slurm services in compute-node ${COMPUTE_NODE} are running."
    done
  fi

  # update slurm in single device and cluster
  for PARTITION_NAME in ${CARME_SLURM_PARTITION_NAME[@]}; do
    NODE_NAME_LIST=$(sinfo -p ${PARTITION_NAME} -Nh --format="%N")
    for NODE_NAME in ${NODE_NAME_LIST[@]}; do
      if grep -q -i "^NodeName=${NODE_NAME}" "${FILE_SLURM_CONFIG}"; then
        NODE_NAME_STRING=$(grep -i "^NodeName=${NODE_NAME}" "${FILE_SLURM_CONFIG}")
        if ! [[ ${NODE_NAME_STRING} == *"Feature=carme"* ]]; then
          sed -i "/NodeName=${NODE_NAME}/s/$/ Feature=carme/" ${FILE_SLURM_CONFIG}
        fi	
      else
        die "[install_slurm.sh]: node name ${NODE_NAME} does not exist or is not active in slurm.conf."
      fi
    done
  done
fi

# delete GPU files if not used ------------------------------------------------------------
if [[ -f "${FILE_GRES_CONFIG}" && -z $(grep '[^[:space:]]' "${FILE_GRES_CONFIG}") ]]; then
  rm ${FILE_GRES_CONFIG}
fi
if [[ -f "${FILE_CARME_GPU_CONFIG}" && -z $(grep '[^[:space:]]' "${FILE_CARME_GPU_CONFIG}") ]]; then
  rm ${FILE_CARME_GPU_CONFIG}
fi

# copy munge.key, slurm.conf, and gres.conf to all compute nodes --------------------------
if [[ ${CARME_SYSTEM} == "multi" ]]; then
log "copying slurm files to compute-nodes..."

  # set compute node list
  if [[ ${CARME_SLURM} == "yes" ]]; then
    NODE_LIST=${CARME_NODE_LIST}
  elif [[ ${CARME_SLURM} == "no" ]]; then
    CLUSTER_NODE_LIST=$(sinfo -Nh --format="%N")
    # remove repetitive names in list
    declare -A uniq
    for k in ${CLUSTER_NODE_LIST} ; do uniq[$k]=1 ; done
    NODE_LIST=${!uniq[@]}
  fi
	
  for COMPUTE_NODE in ${NODE_LIST[@]}; do
    if [[ -f ${FILE_SLURM_CONFIG} ]]; then
      scp -q ${FILE_SLURM_CONFIG} ${COMPUTE_NODE}:${FILE_SLURM_CONFIG} && log "slurm.conf copied to ${COMPUTE_NODE}."
    fi
    if [[ -f ${FILE_GRES_CONFIG} ]]; then
      scp -q ${FILE_GRES_CONFIG} ${COMPUTE_NODE}:${FILE_GRES_CONFIG} && log "gres.conf  copied to ${COMPUTE_NODE}."
    fi
    if [[ -f ${FILE_MUNGE_KEY} ]]; then
      scp -q ${FILE_MUNGE_KEY} ${COMPUTE_NODE}:${FILE_MUNGE_KEY} && log "munge.key  copied to ${COMPUTE_NODE}."
    fi
  done
  rm -f ${FILE_GRES_CONFIG}
fi

# enable systemd --------------------------------------------------------------------------
log "starting slurm services..."

# restart munge
systemctl restart munge
if [[ ${CARME_SYSTEM} == "single" ]]; then
  systemctl is-active --quiet munge && log "munge service is running." \
	                            || die "[install_slurm.sh]: munge.service is not running."
elif [[ ${CARME_SYSTEM} == "multi" ]]; then
  systemctl is-active --quiet munge && log "munge service in head-node running." \
	                            || die "[install_slurm.sh]: munge.service in head-node is not running."
  for COMPUTE_NODE in ${NODE_LIST[@]}; do
    ssh ${COMPUTE_NODE} 'systemctl restart munge'
    MUNGE_STATUS=$(ssh ${COMPUTE_NODE} 'systemctl is-active --quiet munge && echo "running" || echo "not running"')
    [[ $MUNGE_STATUS == "running" ]] && log "munge service in compute-node ${COMPUTE_NODE} is running." \
	                             || die "[install_slurm.sh]: munge.service in compute-node ${COMPUTE_NODE} is not running."
  done
fi

# restart mysql
systemctl restart mysql
if [[ ${CARME_SYSTEM} == "single" ]]; then
  systemctl is-active --quiet mysql && log "mysql service is running." \
	                            || die "[install_slurm.sh]: mysql.service is not running."
elif [[ ${CARME_SYSTEM} == "multi" ]]; then
  systemctl is-active --quiet mysql && log "mysql service in head-node is running." \
	                            || die "[install_slurm.sh]: mysql.service in head-node is not running."
fi

# (re)start slurmdbd
if ! systemctl is-active --quiet slurmdbd
then
  systemctl start slurmdbd
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    systemctl is-active --quiet slurmdbd && log "slurmdbd service is running." \
	                                 || die "[install_slurm.sh]: slurmdbd.service is not running."
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    systemctl is-active --quiet slurmdbd && log "slurmdbd service in head-node is running." \
	                                 || die "[install_slurm.sh]: slurmdbd.service in head-node is not running."
  fi
else
  systemctl restart slurmdbd
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    systemctl is-active --quiet slurmdbd && log "slurmdbd service is running." \
	                                 || die "[install_slurm.sh]: slurmdbd.service is not running."
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    systemctl is-active --quiet slurmdbd && log "slurmdbd service in head-node is running." \
	                                 || die "[install_slurm.sh]: slurmdbd.service in head-node is not running."
  fi
fi

log "waiting for slurmdbd initialization (10s)..."
sleep 10

if [[ ${CARME_SLURM} == "yes" ]]; then

  log "adding the cluster name..."
  if ! sacctmgr list cluster where cluster="${CARME_SLURM_CLUSTER_NAME}" | grep -q ${CARME_SLURM_CLUSTER_NAME}; then
    sacctmgr add cluster ${CARME_SLURM_CLUSTER_NAME} -i
  fi

  log "adding the account..."
  if ! sacctmgr list account where account="${CARME_GROUP}" | grep -q "${CARME_GROUP}"; then
    sacctmgr add account ${CARME_GROUP} -i
  fi

  log "adding the user..."
  if ! sacctmgr list user where user="${CARME_USER}" | grep -q "${CARME_USER}"; then
    sacctmgr create user name="${CARME_USER}" cluster="${CARME_SLURM_CLUSTER_NAME}" account="${CARME_GROUP}" AdminLevel="None" partition="${CARME_SLURM_PARTITION_NAME}" -i
  fi

fi

# (re)start slurmctld
if ! systemctl is-active --quiet slurmctld
then
  systemctl start slurmctld
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    systemctl is-active --quiet slurmctld && log "slurmctld service is running." \
	                                  || die "[install_slurm.sh]: slurmctld.service is not running."
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    systemctl is-active --quiet slurmctld && log "slurmctld service in head-node is running." \
	                                  || die "[install_slurm.sh]: slurmctld.service in head-node is not running."
  fi
else
  systemctl restart slurmctld
  if [[ ${CARME_SYSTEM} == "single" ]]; then
    systemctl is-active --quiet slurmctld && log "slurmctld service is running." \
	                                  || die "[install_slurm.sh]: slurmctld.service is not running."
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then
    systemctl is-active --quiet slurmctld && log "slurmctld service in head-node is running." \
	                                  || die "[install_slurm.sh]: slurmctld.service in head-node is not running."
  fi
  scontrol reconfig
fi


# (re)start slurmd
if [[ ${CARME_SYSTEM} == "single" ]]; then
  if ! systemctl is-active --quiet slurmd
  then
    systemctl start slurmd
    systemctl is-active --quiet slurmd && log "slurmd service is running." \
	                               || die "[install_slurm.sh]: slurmd.service is not running."
  else
    systemctl restart slurmd
    systemctl is-active --quiet slurmd && log "slurmd service is running." \
	                               || die "[install_slurm.sh]: slurmd.service is not running."
    scontrol reconfig
  fi
elif [[ ${CARME_SYSTEM} == "multi" ]]; then
  for COMPUTE_NODE in ${NODE_LIST[@]}; do
    SLURMD_STATUS=$(ssh ${COMPUTE_NODE} 'systemctl is-active --quiet slurmd && echo "running" || echo "not running"')
    if  [[ $SLURMD_STATUS == "running" ]]; then
      ssh ${COMPUTE_NODE} 'systemctl restart slurmd'
      SLURMD_STATUS=$(ssh ${COMPUTE_NODE} 'systemctl is-active --quiet slurmd && echo "running" || echo "not running"')
      if  [[ $SLURMD_STATUS == "running" ]]; then
        log "slurmd service in compute-node ${COMPUTE_NODE} is running."
      else
        die "[install_slurm.sh]: slurmd.service in compute-node ${COMPUTE_NODE} is not running."
      fi
      scontrol reconfig
    else
      ssh ${COMPUTE_NODE} 'systemctl start slurmd'
      SLURMD_STATUS=$(ssh ${COMPUTE_NODE} 'systemctl is-active --quiet slurmd && echo "running" || echo "not running"')
      if  [[ $SLURMD_STATUS == "running" ]]; then
        log "slurmd service in compute-node ${COMPUTE_NODE} is running."
      else
        die "[install_slurm.sh]: slurmd.service in compute-node ${COMPUTE_NODE} is not running."
      fi
    fi
  done
fi

if [[ ${CARME_SLURM} == "yes" ]]; then
  log "slurm successfully installed."
else
  log "slurm successfully configured."
fi
