#-----------------------------------------------------------------------------------------#
#-------------------------------- CarmeConfig.start build --------------------------------#
#-----------------------------------------------------------------------------------------#
  
# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# check compatibility ---------------------------------------------------------------------
log "checking system..."

SYSTEM_ARCH=$(dpkg --print-architecture)
if ! [[ $SYSTEM_ARCH == "arm64" || $SYSTEM_ARCH == "amd64"  ]];then
  die "[config.sh]: amd64 and arm64 architectures are supported. Yours is $SYSTEM_ARCH. Please contact us."
fi

SYSTEM_HDWR=$(uname -m)
if ! [[ $SYSTEM_HDWR == "aarch64" || $SYSTEM_HDWR == "x86_64"  ]];then
  die "[config.sh]: aarch64 and x86_64 hardwares are supported. Yours is $SYSTEM_HDWR. Please contact us."
fi

SYSTEM_OS=$(uname -s)
if ! [ ${SYSTEM_OS,} = "linux" ]; then
  die "[config.sh]: linux OS is supported. Yours is ${SYSTEM_OS,}. Please contact us."
fi

SYSTEM_DIST=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
if ! [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian"  ]];then
  die "[config.sh]: ubuntu and debian distros are supported. Yours is ${SYSTEM_DIST}. Please contact us."
fi

# set the config file ---------------------------------------------------------------------
log "setting CarmeConfig.start..."

# welcome message -------------------------------------------------------------------------
CHECK_CONFIG_MESSAGE=$"
##########################################################
#######     Welcome to Carme-demo ${CARME_VERSION} Config     #######
##########################################################

To create the config file, we need to ask a few questions. 
To exit, press \`Ctrl + C\`  at any time.
(1/8) Do you want to proceed? [y/N]:"

read -rp "${CHECK_CONFIG_MESSAGE} " REPLY
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  die "[config.sh]: config file creation stopped."
fi

# set system ------------------------------------------------------------------------------
REPLY=""
CHECK_SYSTEM_MESSAGE=$'\n(2/8) Do you want to install Carme-demo in a single device or in a cluster?\nType `single` for a single device or `multi` for a cluster [single/multi]:'
while ! [[ $REPLY == "single" || $REPLY == "multi" ]]; do
  read -rp "${CHECK_SYSTEM_MESSAGE} " REPLY
  if ! [[ $REPLY == "single" || $REPLY == "multi" ]]; then
    CHECK_SYSTEM_MESSAGE=$'You did not type `single` or `multi`. Please try again [single/multi]:'
  fi
  CARME_SYSTEM=$REPLY
done

# set head-node / login-node --------------------------------------------------------------
if [[ ${CARME_SYSTEM} == "single" ]]; then
  HEAD_NODE="localhost"
  LOGIN_NODE="localhost"
  LOGIN_NODE_IP="127.0.0.1"

elif [[ ${CARME_SYSTEM} == "multi" ]]; then
  CHECK_HEADNODE_MESSAGE=$'\n(2/8 (1/2)) Are you in the head-node?\nCarme-demo must be installed in the head-node. [y/N]:'
  read -rp "${CHECK_HEADNODE_MESSAGE} " REPLY
  if ! [[ $REPLY =~ ^[Yy]$ ]]; then
    die "[config.sh]: config file creation stopped. You are not in the head-node."
  else
    HEAD_NODE=$(hostname -s | awk '{print $1}')
    LOGIN_NODE=$(hostname -s | awk '{print $1}')
    LOGIN_NODE_IP=$(hostname -I | awk '{print $1}')
  fi
fi

# set compute-nodes -----------------------------------------------------------------------
if [[ ${CARME_SYSTEM} == "single" ]]; then
  COMPUTE_NODES="localhost"

elif [[ ${CARME_SYSTEM} == "multi" ]]; then
  CHECK_COMPUTENODES_MESSAGE=$'\n(2/8 (2/2)) Type the compute-nodes IPs or hostnames.\nUse a blank space to separate them [IPs/hostnames]:'
  read -rp "${CHECK_COMPUTENODES_MESSAGE} " REPLY
  MY_COMPUTE_NODES=($REPLY)
  COMPUTE_NODES=""
  echo checking...
  echo ""
  for MY_COMPUTE_NODE in ${MY_COMPUTE_NODES[@]}; do
    if ! ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking="no" $MY_COMPUTE_NODE true &>/dev/null
    then
      die "[config.sh]: ssh to ${MY_COMPUTE_NODE} failed. Carme-demo requires that you ssh to the compute-nodes without a password. Refer to our documentation and try again."
    else
      MY_COMPUTE_NODE_HOSTNAME=$(ssh ${MY_COMPUTE_NODE} 'echo "$(hostname -s | awk '\''{print $1}'\'')"')
      if [[ ${MY_COMPUTE_NODE_HOSTNAME} == ${HEAD_NODE} ]]; then
        die "[config.sh]: Your compute-node cannot be your head-node. Please do not use \`${MY_COMPUTE_NODE}\` as a compute-node."
      elif [[ ${MY_COMPUTE_NODE_HOSTNAME} == ${LOGIN_NODE} ]]; then
        die "[config.sh]: Your compute-node cannot be your login-node. Please do not use \`${MY_COMPUTE_NODE}\` as a compute-node."
      else
        echo "Compute node ${MY_COMPUTE_NODE} will be used."
        COMPUTE_NODES+=" ${MY_COMPUTE_NODE_HOSTNAME}"
        COMPUTE_NODES=$(echo "${COMPUTE_NODES}" | sed 's/^ *//')
      fi
    fi
  done
fi

# set users ------------------------------------------------------------------------------
REPLY=""
CHECK_USERS_MESSAGE=$'\n(3/8) Do you want to use a single-user or multi-user interface?\nType `single` for personal use or `multi` for multi-users [single/multi]:'
while ! [[ $REPLY == "single" || $REPLY == "multi" ]]; do
  read -rp "${CHECK_USERS_MESSAGE} " REPLY
  if ! [[ $REPLY == "single" || $REPLY == "multi" ]]; then
    CHECK_USERS_MESSAGE=$'You did not type `single` or `multi`. Please try again [single/multi]:'
  fi
  CARME_USERS=$REPLY
done

# set ldap -------------------------------------------------------------------------------
REPLY=""
if [[ ${CARME_USERS} == "single" ]]; then
  CHECK_LDAP_MESSAGE=$'\n(4/8) Carme-demo single-user does not require ldap user management tool. It won\'t be installed. Do you want to proceed? [y/N]:'
  while ! [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" || $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no" ]]; do
    read -rp "${CHECK_LDAP_MESSAGE} " REPLY
    if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
      CARME_LDAP="null"
    elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
      die "config file creation stopped."
    else
      CHECK_LDAP_MESSAGE=$'You did not choose yes or no. Please try again [y/N]:'
    fi
  done

elif [[ ${CARME_USERS} == "multi" ]]; then
  CHECK_LDAP_MESSAGE=$'\n(4/8) Carme-demo multi-user requires ldap user management tool. Do you want to install it?\nType `No` if you want Carme-demo to use an already existing ldap in your system. [y/N]:'
  while ! [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" || $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no" ]]; do
    read -rp "${CHECK_LDAP_MESSAGE} " REPLY
    if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
      CARME_LDAP="yes"
    elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
      CARME_LDAP="no"
    else
      CHECK_LDAP_MESSAGE=$'You did not choose yes or no. Please try again [y/N]:'
    fi
  done
fi

# set username ---------------------------------------------------------------------------	
if [[ ${CARME_USERS} == "single" ]]; then
  CHECK_USER_MESSAGE=$'\n(5/8) Type your username (root user is not allowed) [username]:'
elif [[ ${CARME_USERS} == "multi" ]]; then
  CHECK_USER_MESSAGE=$'\n(5/8) Create a Carme admin name [admin name]:'
fi

read -rp "${CHECK_USER_MESSAGE} " REPLY
CARME_USER=$REPLY

if [[ ${CARME_USERS} == "single" || ${CARME_LDAP} == "no" ]]; then
  CARME_UID="$(id -u ${CARME_USER} 2>/dev/null)" || CARME_UID=""
  while [[ -z ${CARME_UID} || ${CARME_UID} -lt 1000 ]]; do
    if [[ -z ${CARME_UID} ]]; then
      CHECK_UID_MESSAGE=$"User \"${CARME_USER}\" does not exist in your Linux system. Please try again:"
      read -rp "${CHECK_UID_MESSAGE} " REPLY
    elif [[ ${CARME_UID} -lt 1000 ]]; then
      if [[ -z $CARME_USER ]]; then
        CHECK_UID_MESSAGE=$"You did not type a username. Please try again:"
        read -rp "${CHECK_UID_MESSAGE} " REPLY
      else
        CHECK_UID_MESSAGE=$"User ${CARME_USER} is not a valid user. UID must be larger than 999. Yours is ${CARME_UID}. Please try again:"
        read -rp "${CHECK_UID_MESSAGE} " REPLY
      fi
    fi
    CARME_USER=$REPLY
    CARME_UID="$(id -u ${CARME_USER} 2>/dev/null)" || CARME_UID=""
  done
  
  CARME_GROUP=$(id -gn ${CARME_USER})
  CARME_HOME=$(eval echo ~${CARME_USER})
else
  # CARME_UID will be assigned by LDAP
  # CARME_USER will be created in LDAP
  CARME_GROUP=carme-admin
  # CARME_HOME should exist?
fi

# set database ---------------------------------------------------------------------------
REPLY=""
if [[ ${SYSTEM_ARCH} == "amd64" && ${SYSTEM_DIST} == "ubuntu" ]]; then
  CARME_DB_SERVER="mysql"
else
  CARME_DB_SERVER="mariadb"
fi

CHECK_DATABASE_MESSAGE=$"
(6/8) Carme-demo requires ${CARME_DB_SERVER} database management tool. Do you want to install it? 
Type \`No\` if you want Carme-demo to use an already existing ${CARME_DB_SERVER} in your system [y/N]:"
while ! [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" || $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no" ]]; do
  read -rp "${CHECK_DATABASE_MESSAGE} " REPLY
  if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
    CARME_DB="yes"
  elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
    CARME_DB="no"
  else
    CHECK_DATABASE_MESSAGE=$'You did not choose yes or no. Please try again [y/N]:'
  fi
done

# set database parameters ----------------------------------------------------------------
DB_PASS_STOP=""
if [[ ${CARME_DB} == "no" ]]; then
  CHECK_DATABASE_PASSWORD_MESSAGE=$"
(6/8 (1/1)) Carme-demo requires access to your already existing ${CARME_DB_SERVER} server. 
Type your ${CARME_DB_SERVER} root password (if no password, press enter) [mysql -uroot -p]:"
  while ! [[ ${DB_PASS_STOP} == "yes" ]]
  do
    read -rsp "${CHECK_DATABASE_PASSWORD_MESSAGE} " REPLY && echo
    export MYSQL_PWD=${REPLY}
    if ! mysql -uroot -e 'quit' &> /dev/null; then
      CHECK_DATABASE_PASSWORD_MESSAGE=$"You did not type the correct ${CARME_DB_SERVER} root password. Please try again. [mysql -uroot -p]:"
    else
      CARME_PASSWORD_MYSQL=${REPLY}
      CARME_DB_DEFAULT_PORT=$(mysql -uroot -e 'show global variables like "port"')
      CARME_DB_DEFAULT_PORT=$(echo $CARME_DB_DEFAULT_PORT | grep -o -E '[0-9]+')
      [[ -z ${CARME_DB_DEFAULT_PORT} ]] && die "[config.sh]: ${CARME_DB_SERVER} command \`show global variables like \"port\"\` must list the port. Verify and try again."
      SCHEMA=$(mysql -uroot -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='webfrontend'")
      if [[ ${SCHEMA} =~ "webfrontend" ]]; then
	DB_NAME_STOP=""
	CHECK_DATABASE_NAME_MESSAGE=$"
Type a name for your Carme-demo database [database name]: "
        while ! [[ ${DB_NAME_STOP} == "yes" ]]
	do
          read -rp "${CHECK_DATABASE_NAME_MESSAGE} " REPLY
	  if [[ $REPLY =~ ^[0-9a-zA-Z]+$ ]]; then
            SCHEMA=$(mysql -uroot -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${REPLY}'")
	    if [[ ${SCHEMA} =~ "${REPLY}" ]]; then 
	      CHECK_DATABASE_NAME_MESSAGE=$"\`${REPLY}\` database already exists in your ${CARME_DB_SERVER} server. To use it, Carme will empty it. Do you want to proceed?
Type \`Yes\` if you are ok emptying your database. Type \`No\` if you prefer to use a different database name [y/N]: "
              while ! [[ ${DB_EMPTY_STOP} == "yes" ]]
	      do
                read -rp "${CHECK_DATABASE_NAME_MESSAGE} " REPLY
                if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
                  CARME_DB_DEFAULT_NAME="webfrontend"
		  DB_NAME_STOP="yes"
		  DB_EMPTY_STOP="yes"
                elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
                  CHECK_DATABASE_NAME_MESSAGE=$"Type another name for your Carme database [database name]: "
		  DB_EMPTY_STOP="yes"
                else
                  CHECK_DATABASE_NAME_MESSAGE=$'You did not choose yes or no. Please try again [y/N]:'
                fi
              done		
            else
	      CARME_DB_DEFAULT_NAME="${REPLY}"
	      DB_NAME_STOP="yes"
	    fi
          else
	    CHECK_DATABASE_NAME_MESSAGE=$"Sorry, special characters are not allowed.
Type another name for your Carme database [database name]: "
	  fi
	done
      else
        CARME_DB_DEFAULT_NAME="webfrontend"
      fi
      DB_PASS_STOP="yes"
    fi
  done
elif [[ ${CARME_DB} == "yes" ]]; then
  CARME_PASSWORD_MYSQL="mysqlpwd"
  CARME_DB_DEFAULT_NAME="webfrontend"
  CARME_DB_DEFAULT_PORT=3306 
fi

# set slurm ------------------------------------------------------------------------------
REPLY=""
CHECK_SLURM_MESSAGE=$'\n(7/8) Carme-demo requires slurm workload management tool. Do you want to install it? \nType `No` if you want Carme-demo to use an already existing slurm in your system. [y/N]:'
while ! [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" || $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no" ]]; do
  read -rp "${CHECK_SLURM_MESSAGE} " REPLY
  if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
    CARME_SLURM="yes"
  elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
    CARME_SLURM="no"
  else
    CHECK_SLURM_MESSAGE=$'You did not choose yes or no. Please try again [y/N]:'
  fi
done

# set slurmdbd.conf and slurm.conf parameters ----------------------------------------------
if [[ ${CARME_SLURM} == "no" ]]; then
  PATH_ETC_SLURM=$(dpkg -L slurmctld | grep '/etc/slurm' | head -n1)
  FILE_SLURMDBD_CONF=${PATH_ETC_SLURM}/slurmdbd.conf
  FILE_SLURM_CONF=${PATH_ETC_SLURM}/slurm.conf

  if ! [[ -f ${FILE_SLURMDBD_CONF} ]]; then
    die "[config.sh]: ${FILE_SLURMDBD_CONF} does not exist. Please, contact us. Carme requires \`slurmdbd.conf\`."
  elif ! [[ -f ${FILE_SLURM_CONF} ]]; then
    die "[config.sh]: ${FILE_SLURM_CONF} does not exist. Please, contact us. Carme requires \`slurm.conf\`."
  else
    CARME_PASSWORD_SLURM=$(get_variable StoragePass ${FILE_SLURMDBD_CONF})
    CARME_DB_SLURM_USER=$(get_variable StorageUser ${FILE_SLURMDBD_CONF})
    CARME_DB_SLURM_PORT=$(get_variable StoragePort ${FILE_SLURMDBD_CONF})
    CARME_DB_SLURM_NAME=$(get_variable StorageLoc ${FILE_SLURMDBD_CONF})
    CARME_SLURM_SLURMD_PORT=$(get_variable SlurmdPort ${FILE_SLURM_CONF})
    CARME_SLURM_CLUSTER_NAME=$(get_variable ClusterName ${FILE_SLURM_CONF})
    CARME_SLURM_SLURMCTLD_PORT=$(get_variable SlurmctldPort ${FILE_SLURM_CONF})

    [[ -z ${CARME_PASSWORD_SLURM} ]] && die "[config.sh]: StoragePass in slurmdbd.conf not set."
    [[ -z ${CARME_DB_SLURM_USER} ]] && die "[config.sh]: StorageUser in slurmdbd.conf not set."
    [[ -z ${CARME_DB_SLURM_PORT} ]] && CARME_DB_SLURM_PORT=3306
    [[ -z ${CARME_DB_SLURM_NAME} ]] && CARME_DB_SLURM_NAME="slurm_acct_db"
    [[ -z ${CARME_SLURM_SLURMD_PORT} ]] && CARME_SLURM_SLURMD_PORT=6818
    [[ -z ${CARME_SLURM_CLUSTER_NAME} ]] && die "[config.sh]: ClusterName in slurm.conf not set."
    [[ -z ${CARME_SLURM_SLURMCTLD_PORT} ]] && CARME_SLURM_SLURMCTLD_PORT=6817
  fi
elif [[ ${CARME_SLURM} == "yes" ]]; then
  CARME_PASSWORD_SLURM="slurmpwd"
  CARME_DB_SLURM_USER="slurm"
  CARME_DB_SLURM_PORT=3306
  CARME_DB_SLURM_NAME="slurm_acct_db"
  CARME_SLURM_SLURMD_PORT=6818
  CARME_SLURM_CLUSTER_NAME="mycluster"
  CARME_SLURM_SLURMCTLD_PORT=6817
fi

# set slurm partitions -------------------------------------------------------------------
AGREE=""
if [[ ${CARME_SLURM} == "no" ]]; then
	CHECK_PARTITIONNAMES_MESSAGE=$'\n(7/8 (1/2)) Type the slurm partition name(s) that you want Carme to use (the partition must exist in `slurm.conf`). \nFor multiple partitions, use a blank space to separate them [partition name(s)]:'
  while ! [[ $AGREE == "yes" ]]; do
    read -rp "${CHECK_PARTITIONNAMES_MESSAGE} " REPLY
    MY_PARTITION_NAMES=($REPLY)
    PARTITION_NAMES=""
    echo "checking..."
    echo ""
    AT_LEAST_ONE_PARTITION_EXISTS=""
    for MY_PARTITION_NAME in ${MY_PARTITION_NAMES[@]}; do
      if grep -q -i "^PartitionName=${MY_PARTITION_NAME}" "${FILE_SLURM_CONF}"; then
	echo "PartitionName=${MY_PARTITION_NAME} will be used."
	PARTITION_NAMES+=" ${MY_PARTITION_NAME}"
	PARTITION_NAMES=$(echo "${PARTITION_NAMES}" | sed 's/^ *//')
	AT_LEAST_ONE_PARTITION_EXISTS="yes"
      else
        echo "PartitionName=${MY_PARTITION_NAME} will be omitted (it does not exist or is not active)."
      fi    
    done
    if [[ $AT_LEAST_ONE_PARTITION_EXISTS == "yes" ]]; then
      REPLY=""
      RECHECK_PARTITIONNAMES_MESSAGE=$"
(6/8 (2/2)) Do you agree with the partitions to be used?
Type \`No\` if you think you made a typo and need to fix the partition list [y/N]:"
      while ! [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" || $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no" ]]; do
        read -rp "${RECHECK_PARTITIONNAMES_MESSAGE} " REPLY
        if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
          AGREE="yes"
        elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
          AGREE="no"
	  CHECK_PARTITIONNAMES_MESSAGE=$'\n(7/8 (1/2)) Type the slurm partition name(s) that you want Carme to use (the partition must exist in `slurm.conf`. \nFor multiple partitions, use a blank space to separate them [partition name(s)]:'
        else
          RECHECK_PARTITIONNAMES_MESSAGE=$'You did not choose yes or no. Please try again. Do you agree? [y/N]:'
        fi
      done
    else
      REPLY=""
      AGREE="no"
      CHECK_PARTITIONNAMES_MESSAGE=$'\nSorry, the partitions were not found. Try again. \nFor multiple partitions, use a blank space to separate them [partition name(s)]:'
    fi
  done
elif [[ ${CARME_SLURM} == "yes" ]]; then
  PARTITION_NAMES="carme"
fi

# set message -----------------------------------------------------------------------------
if [[ ${CARME_DB} == "no" && ${CARME_SLURM} == "yes" && (${CARME_LDAP} == "yes" || ${CARME_LDAP} == "null") ]]; then
    MESSAGE_IMPORTANT="You have chosen an already existing database management tool. This requires additional modifications in the config file. Please, create the config file and modify DB parameters. Refer to our documentation for advanced modifications."
elif [[ ${CARME_DB} == "yes" && ${CARME_SLURM} == "no" && (${CARME_LDAP} == "yes" || ${CARME_LDAP} == "null") ]]; then
    MESSAGE_IMPORTANT="You have chosen an already existing workload management tool. This requires additional modifications in the config file. Please, create the config file and modify SLURM parameters. Refer to our documentation for advanced modifications."
elif [[ ${CARME_DB} == "yes" && ${CARME_SLURM} == "yes" && ${CARME_LDAP} == "no" ]]; then
    MESSAGE_IMPORTANT="You have chosen an already existing user management tool. This requires additional modifications in the config file. Please, create the config file and modify LDAP parameters. Refer to our documentation for advanced modifications."
elif [[ ${CARME_DB} == "no" && ${CARME_SLURM} == "no" && (${CARME_LDAP} == "yes" || ${CARME_LDAP} == "null") ]]; then
    MESSAGE_IMPORTANT="You have chosen already existing management tools. This requires additional modifications in the config file. Please, create the config file and modify DB and SLURM parameters. Refer to our documentation for advanced modifications."
elif [[ ${CARME_DB} == "no" && ${CARME_SLURM} == "yes" && ${CARME_LDAP} == "no" ]]; then
    MESSAGE_IMPORTANT="You have chosen already existing management tools. This requires additional modifications in the config file. Please, create the config file and modify DB and LDAP parameters. Refer to our documentation for advanced modifications."
elif [[ ${CARME_DB} == "yes" && ${CARME_SLURM} == "no" && ${CARME_LDAP} == "no" ]]; then
    MESSAGE_IMPORTANT="You have chosen already existing management tools. This requires additional modifications in the config file. Please, create the config file and modify SLURM and LDAP parameters. Refer to our documentation for advanced modifications."
elif [[ ${CARME_DB} == "no" && ${CARME_SLURM} == "no" && ${CARME_LDAP} == "no" ]]; then
    MESSAGE_IMPORTANT="You have chosen already existing management tools. This requires additional modifications in the config file. Please, create the config file and modifiy DB, SLURM, and LDAP parameters. Refer to our documentation for advanced modifications."
elif [[ ${CARME_DB} == "yes" && ${CARME_SLURM} == "yes" && (${CARME_LDAP} == "yes" || ${CARME_LDAP} == "null") ]]; then
  MESSAGE_IMPORTANT="Please refer to our documentation for advanced modifications."
fi

if [[ ${CARME_LDAP} == "yes" || ${CARME_LDAP} == "no" ]]; then
  CHECK_ALL_MESSAGE=$"
The config file will be created with the following information: 

CARME_UID=\"${CARME_UID}\"
CARME_USER=\"${CARME_USER}\" 
CARME_HOME=\"${CARME_HOME}\" 
CARME_GROUP=\"${CARME_GROUP}\"  
CARME_USERS=\"${CARME_USERS}\" 
CARME_SYSTEM=\"${CARME_SYSTEM}\"
CARME_DB_SERVER=\"${CARME_DB_SERVER}\"
CARME_DB=\"${CARME_DB}\"
CARME_LDAP=\"${CARME_LDAP}\"
CARME_SLURM=\"${CARME_SLURM}\"

You can manually modify this information once the config file is created. 

IMPORTANT:
${MESSAGE_IMPORTANT}

(8/8) Do you want proceed and create the config file? [y/N]:"
else
  CHECK_ALL_MESSAGE=$"
The config file will be created with the following information: 

CARME_UID=\"${CARME_UID}\"
CARME_USER=\"${CARME_USER}\" 
CARME_HOME=\"${CARME_HOME}\" 
CARME_GROUP=\"${CARME_GROUP}\"  
CARME_USERS=\"${CARME_USERS}\" 
CARME_SYSTEM=\"${CARME_SYSTEM}\"
CARME_DB=\"${CARME_DB}\"
CARME_SLURM=\"${CARME_SLURM}\"

You can manually modify this information once the config file is created.

IMPORTANT:
${MESSAGE_IMPORTANT}

(8/8) Do you want to proceed and create the config file? [y/N]:"
fi
read -rp "${CHECK_ALL_MESSAGE} " REPLY
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  die "config file creation stopped."
fi

# create the config file ------------------------------------------------------------------
log "creating CarmeConfig.start..."

if [[ -f "CarmeConfig.start" ]]; then
  rm "CarmeConfig.start"
fi
touch "CarmeConfig.start"

[[ -f "CarmeConfig.start" ]] || echo "ERROR: CarmeConfig.start was not created. Please contact us."

cat << EOF >> CarmeConfig.start
#-----------------------------------------------------------------------------------------#
#----------------------------------- CarmeConfig.start -----------------------------------#
#-----------------------------------------------------------------------------------------#

# SYSTEM ----------------------------------------------------------------------------------
SYSTEM_OS="${SYSTEM_OS}"
SYSTEM_ARCH="${SYSTEM_ARCH}"
SYSTEM_HDWR="${SYSTEM_HDWR}"
SYSTEM_DIST="${SYSTEM_DIST}"

# USER/ADMIN ------------------------------------------------------------------------------
CARME_UID="${CARME_UID}"
CARME_USER="${CARME_USER}"
CARME_HOME="${CARME_HOME}"
CARME_GROUP="${CARME_GROUP}"
CARME_USERS="${CARME_USERS}"
CARME_SYSTEM="${CARME_SYSTEM}"
CARME_TIMEZONE="Europe/Berlin"

# PASSWORDS -------------------------------------------------------------------------------
CARME_PASSWORD_USER="usrpwd"
CARME_PASSWORD_MYSQL="${CARME_PASSWORD_MYSQL}"
CARME_PASSWORD_SLURM="${CARME_PASSWORD_SLURM}"
CARME_PASSWORD_DJANGO="djangopwd"

# DATABASE --------------------------------------------------------------------------------
CARME_DB="${CARME_DB}"
CARME_DB_SERVER="${CARME_DB_SERVER}"

CARME_DB_DEFAULT_NAME="${CARME_DB_DEFAULT_NAME}"
CARME_DB_DEFAULT_NODE="${HEAD_NODE}"
CARME_DB_DEFAULT_HOST="${HEAD_NODE}"
CARME_DB_DEFAULT_USER="django"
CARME_DB_DEFAULT_PORT=${CARME_DB_DEFAULT_PORT}

CARME_DB_SLURM_NAME="${CARME_DB_SLURM_NAME}"
CARME_DB_SLURM_NODE="${HEAD_NODE}"
CARME_DB_SLURM_HOST="${HEAD_NODE}"
CARME_DB_SLURM_USER="${CARME_DB_SLURM_USER}"
CARME_DB_SLURM_PORT=${CARME_DB_SLURM_PORT}

# SLURM -----------------------------------------------------------------------------------
CARME_SLURM="${CARME_SLURM}"
CARME_SLURM_CLUSTER_NAME="${CARME_SLURM_CLUSTER_NAME}"
CARME_SLURM_PARTITION_NAME="${PARTITION_NAMES}"
CARME_SLURM_SLURMCTLD_PORT=${CARME_SLURM_SLURMCTLD_PORT}
CARME_SLURM_SLURMD_PORT=${CARME_SLURM_SLURMD_PORT}
CARME_MUNGE_PATH_RUN="/var/run/munge"
CARME_MUNGE_FILE_KEY="/etc/munge/munge.key"

# VENDORS ---------------------------------------------------------------------------------
# go to https://github.com/conda-forge/miniforge/releases for a different version.
MAMBAFORGE_VERSION=23.11.0-0
# go to https://github.com/sylabs/singularity/releases for a different version.
SINGULARITY_VERSION=3.11.4
# go to https://github.com/traefik/traefik/releases for a different version.
PROXY_VERSION=2.11.2
# go to https://go.dev/dl/ for a different version.
GO_VERSION=1.20.6

# FRONTEND --------------------------------------------------------------------------------
# got to https://djecrety.ir to create a key
CARME_FRONTEND_KEY="3nb5&c!y0f&myadrbkp+v67m9ps8(+(!eksyq!5&5z&mlwx_=="
CARME_FRONTEND_NODE="${LOGIN_NODE}"
CARME_FRONTEND_URL="localhost"
CARME_FRONTEND_IP="${LOGIN_NODE_IP}"
CARME_FRONTEND_ID="Carme"
CARME_FRONTEND_PORT=8888

# BACKEND ---------------------------------------------------------------------------------
CARME_BACKEND_NODE="${HEAD_NODE}"
CARME_BACKEND_PORT=56798

# NODES -----------------------------------------------------------------------------------
CARME_NODE_LIST="${COMPUTE_NODES}"
CARME_NODE_FS="yes"
CARME_NODE_SSHD="yes"
CARME_NODE_SSD_PATH="/scratch"
CARME_NODE_TMP_PATH="/tmp"
EOF

if [[ ${CARME_LDAP} == "yes" || ${CARME_LDAP} == "no" ]]; then
  sed -i "/CARME_PASSWORD_USER/a CARME_PASSWORD_LDAP=\"ldappwd\"" CarmeConfig.start
  sed -i "/GO_VERSION/a # LDAP ------------------------------------------------------------------------------------" CarmeConfig.start
  sed -i "/GO_VERSION/G" CarmeConfig.start
  sed -i "/# LDAP ---/a CARME_LDAP=\"${CARME_LDAP}\"\n\
CARME_LDAP_SERVER_PROTO=\"ldap://\"\n\
CARME_LDAP_SERVER_IP=\"${LOGIN_NODE_IP}\"\n\
CARME_LDAP_BASE_DN=\"dc=carme,dc=local\"\n\
CARME_LDAP_BIND_DN=\"cn=admin,dc=nodomain\"\n\
CARME_LDAP_SERVER_PW=\"ldappwdroot\"\n\
  " CarmeConfig.start
fi

[[ -s CarmeConfig.start ]] && log "CarmeConfig.start successfully created." \
	                   || log "CarmeConfig.start was not set. Please contact us."
