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
  die "amd64 and arm64 architectures are supported. Yours is $SYSTEM_ARCH. Please contact us."
fi

SYSTEM_HDWR=$(uname -m)
if ! [[ $SYSTEM_HDWR == "aarch64" || $SYSTEM_HDWR == "x86_64"  ]];then
  die "aarch64 and x86_64 hardwares are supported. Yours is $SYSTEM_HDWR. Please contact us."
fi

SYSTEM_OS=$(uname -s)
if ! [ ${SYSTEM_OS,} = "linux" ]; then
  die "linux OS is supported. Yours is ${SYSTEM_OS,}. Please contact us."
fi

SYSTEM_DIST=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
if ! [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian"  ]];then
  die "ubuntu and debian distros are supported. Yours is ${SYSTEM_DIST}. Please contact us."
fi


# set the config file ---------------------------------------------------------------------
log "setting CarmeConfig.start..."

# welcome message -------------------------------------------------------------------------
CHECK_CONFIG_MESSAGE=$"
##########################################################
#######     Welcome to Carme-demo ${CARME_VERSION} Config     #######
##########################################################

To create the config file, we need to ask a few questions.
(1/8) Do you want to proceed? [y/N]:"

read -rp "${CHECK_CONFIG_MESSAGE} " REPLY
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  die "config file creation stopped."
fi

# set system ------------------------------------------------------------------------------
REPLY=""
CHECK_SYSTEM_MESSAGE=$'\n(2/8) Do you want to install Carme-demo in a single device or in a cluster? \nType `single` for a single device or `multi` for a cluster [single/multi]:'
while ! [[ $REPLY == "single" || $REPLY == "multi" ]]; do
  read -rp "${CHECK_SYSTEM_MESSAGE} " REPLY
  if ! [[ $REPLY == "single" || $REPLY == "multi" ]]; then
    CHECK_SYSTEM_MESSAGE=$'You did not type `single` or `multi`. Please try again [single/multi]:'
  fi
  CARME_SYSTEM=$REPLY
done

# set head-node ----------------------------------------------------------------------------
if [[ ${CARME_SYSTEM} == "multi" ]]; then
  CHECK_HEADNODE_MESSAGE=$'\n(2/8 (1/2)) Are you in the head-node?\nCarme-demo must be installed in the head-node. [y/N]:'
  read -rp "${CHECK_HEADNODE_MESSAGE} " REPLY
  if ! [[ $REPLY =~ ^[Yy]$ ]]; then
    die "config file creation stopped. You are not in the head-node."
  else
    HEAD_NODE=$(hostname -s)
    LOGIN_NODE=$(hostname -s)
    LOGIN_NODE_IP=$(echo $(hostname -I))
  fi
else
  HEAD_NODE="localhost"
  LOGIN_NODE="localhost"
  LOGIN_NODE_IP="127.0.0.1"
fi

# set login-node ----------------------------------------------------------------------------
#if [[ ${CARME_SYSTEM} == "multi" ]]; then
#  CHECK_LOGINNODE_MESSAGE=$"
#(2/8 (2/3)) Type the login-node IP.
#If the head-node is also the login-node, type the head-node IP, i.e., $(hostname -I) [IP]:"
#  read -rp "${CHECK_LOGINNODE_MESSAGE} " REPLY
#  if ! ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking="no" $REPLY true &>/dev/null
#  then
#    die "ssh to ${REPLY} failed. Carme requires that you ssh to the login-node without a password. Refer to our documentation and try again."
#  else
#    LOGIN_NODE=$(ssh ${REPLY} 'echo "$(hostname -s)"')
#  fi
#else
#  LOGIN_NODE="localhost"
#fi

# set compute-nodes -------------------------------------------------------------------------
if [[ ${CARME_SYSTEM} == "multi" ]]; then
  CHECK_COMPUTENODES_MESSAGE=$'\n(2/8 (2/2)) Type the compute-nodes IPs. 
Use a blank space to separate them [IPs]:'
  read -rp "${CHECK_COMPUTENODES_MESSAGE} " REPLY
  MY_COMPUTE_NODES=($REPLY)
  COMPUTE_NODES=""
  echo checking...
  for MY_COMPUTE_NODE in ${MY_COMPUTE_NODES[@]}; do
    if ! ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking="no" $MY_COMPUTE_NODE true &>/dev/null
    then
      die "ssh to ${MY_COMPUTE_NODE} failed. Carme-demo requires that you ssh to the compute-nodes without a password. Refer to our documentation and try again."
    else
      COMPUTE_NODES+=" $(ssh ${MY_COMPUTE_NODE} 'echo "$(hostname -s)"')"
      COMPUTE_NODES=$(echo "${COMPUTE_NODES}" | sed 's/^ *//')
    fi
  done
else
  COMPUTE_NODES="localhost"
fi

# set users ------------------------------------------------------------------------------
#REPLY=""
#CHECK_USERS_MESSAGE=$'\n(3/8) Do you want to use a single-user or multi-user interface? \nType `single` for personal use or `multi` for multi-users [single/multi]:'
#while ! [[ $REPLY == "single" || $REPLY == "multi" ]]; do
#  read -rp "${CHECK_USERS_MESSAGE} " REPLY
#  if ! [[ $REPLY == "single" || $REPLY == "multi" ]]; then
#    CHECK_USERS_MESSAGE=$'You did not type `single` or `multi`. Please try again [single/multi]:'
#  fi
#  CARME_USERS=$REPLY
#done
REPLY=""
CHECK_USERS_MESSAGE=$'\n(3/8) Do you want to proceed with a single-user installation? \nCarme-demo does not support multi-users [y/N]:'
read -rp "${CHECK_USERS_MESSAGE} " REPLY
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  die "config file creation stopped."
else
  CARME_USERS="single"
fi

# set username ---------------------------------------------------------------------------	
#CHECK_USER_MESSAGE=$'\n(4/8) Please enter your username (root user is not allowed). If you use a multi-user interface, this user becomes the admin:'
CHECK_USER_MESSAGE=$'\n(4/8) Please enter your username (root user is not allowed):'

read -rp "${CHECK_USER_MESSAGE} " REPLY
CARME_USER=$REPLY

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

# set database ---------------------------------------------------------------------------
REPLY=""
if [[ ${SYSTEM_ARCH} == "amd64" && ${SYSTEM_DIST} == "ubuntu" ]]; then
  CHECK_DATABASE_MESSAGE=$'\n(5/8) Do you want to install mysql database management tool? \nType `No` if you want Carme-demo to use an already existing mysql in your system [y/N]:'
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
  CARME_DB_SERVER="mysql"
else	
  CHECK_DATABASE_MESSAGE=$'\n(5/9) Do you want to install mariadb database management tool? \nType `No` if you want Carme-demo to use an already existing mariadb in your system [y/N]:'
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
  CARME_DB_SERVER="mariadb"
fi

# set slurm ------------------------------------------------------------------------------
REPLY=""
CHECK_SLURM_MESSAGE=$'\n(6/8) Do you want to install slurm workload management tool? \nType `No` if you want Carme-demo to use an already existing slurm in your system. [y/N]:'
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

# set ldap -------------------------------------------------------------------------------
REPLY=""
if [[ ${CARME_USERS} == "single" ]]; then
  CHECK_LDAP_MESSAGE=$'\n(7/8) ldap user management tool won\'t be installed in your system. Do you want to proceed? [y/N]:'
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
else
  CHECK_LDAP_MESSAGE=$'\n(7/8) Do you want to install ldap user management tool? \nType `No` if you want Carme to use an already existing ldap in your system. [y/N]:'
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

(8/8) Do you want proceed and create the config file? [y/N]:"
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
CARME_PASSWORD_MYSQL="mysqlpwd"
CARME_PASSWORD_SLURM="slurmpwd"
CARME_PASSWORD_DJANGO="djangopwd"

# DATABASE --------------------------------------------------------------------------------
CARME_DB="${CARME_DB}"
CARME_DB_SERVER="${CARME_DB_SERVER}"

CARME_DB_DEFAULT_NAME="webfrontend"
CARME_DB_DEFAULT_NODE="${HEAD_NODE}"
CARME_DB_DEFAULT_HOST="${HEAD_NODE}"
CARME_DB_DEFAULT_USER="django"
CARME_DB_DEFAULT_PORT=3306

CARME_DB_SLURM_NAME="slurm_acct_db"
CARME_DB_SLURM_NODE="${HEAD_NODE}"
CARME_DB_SLURM_HOST="${HEAD_NODE}"
CARME_DB_SLURM_USER="slurm"
CARME_DB_SLURM_PORT=3306

# SLURM -----------------------------------------------------------------------------------
CARME_SLURM="${CARME_SLURM}"
CARME_SLURM_CLUSTER_NAME="mycluster"
CARME_SLURM_PARTITION_NAME="carme"
CARME_SLURM_ACCELERATOR_TYPE="cpu"
CARME_SLURM_SLURMCTLD_PORT=6817
CARME_SLURM_SLURMD_PORT=6818

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
  sed -i "/# LDAP ---/a CARME_LDAP=\"${CARME_LDAP}\"" CarmeConfig.start
fi

[[ -s CarmeConfig.start ]] && log "CarmeConfig.start successfully created." \
	                   || log "CarmeConfig.start was not set. Please contact us."
