#!/bin/bash
#-----------------------------------------------------------------------------------------#
#-------------------------------- FRONTEND installation ----------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then

  CARME_UID=$(get_variable CARME_UID ${FILE_START_CONFIG})	
  CARME_LDAP=$(get_variable CARME_LDAP ${FILE_START_CONFIG})
  CARME_USER=$(get_variable CARME_USER ${FILE_START_CONFIG})
  CARME_HOME=$(get_variable CARME_HOME ${FILE_START_CONFIG})
  CARME_USERS=$(get_variable CARME_USERS ${FILE_START_CONFIG})
  CARME_GROUP=$(get_variable CARME_GROUP ${FILE_START_CONFIG})
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_TIMEZONE=$(get_variable CARME_TIMEZONE ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})
  CARME_BACKEND_PORT=$(get_variable CARME_BACKEND_PORT ${FILE_START_CONFIG})
  CARME_BACKEND_NODE=$(get_variable CARME_BACKEND_NODE ${FILE_START_CONFIG})
  CARME_FRONTEND_ID=$(get_variable CARME_FRONTEND_ID ${FILE_START_CONFIG})
  CARME_FRONTEND_KEY=$(get_variable CARME_FRONTEND_KEY ${FILE_START_CONFIG})
  CARME_FRONTEND_URL=$(get_variable CARME_FRONTEND_URL ${FILE_START_CONFIG})
  CARME_FRONTEND_PORT=$(get_variable CARME_FRONTEND_PORT ${FILE_START_CONFIG})
  CARME_FRONTEND_NODE=$(get_variable CARME_FRONTEND_NODE ${FILE_START_CONFIG})
  CARME_PASSWORD_USER=$(get_variable CARME_PASSWORD_USER ${FILE_START_CONFIG})
  CARME_PASSWORD_DJANGO=$(get_variable CARME_PASSWORD_DJANGO ${FILE_START_CONFIG})
  CARME_SLURM_CLUSTER_NAME=$(get_variable CARME_SLURM_CLUSTER_NAME ${FILE_START_CONFIG})
  CARME_SLURM_PARTITION_NAME=$(get_variable CARME_SLURM_PARTITION_NAME ${FILE_START_CONFIG})
  CARME_SLURM_ACCELERATOR_TYPE=$(get_variable CARME_SLURM_ACCELERATOR_TYPE ${FILE_START_CONFIG})

  CARME_DB_SLURM_NAME=$(get_variable CARME_DB_SLURM_NAME ${FILE_START_CONFIG})
  CARME_DB_SLURM_NODE=$(get_variable CARME_DB_SLURM_NODE ${FILE_START_CONFIG})
  CARME_DB_SLURM_HOST=$(get_variable CARME_DB_SLURM_HOST ${FILE_START_CONFIG})
  CARME_DB_SLURM_PORT=$(get_variable CARME_DB_SLURM_PORT ${FILE_START_CONFIG})
  CARME_DB_SLURM_USER=$(get_variable CARME_DB_DEFAULT_USER ${FILE_START_CONFIG})
  CARME_DB_SLURM_ENGINE=$(get_variable CARME_DB_SLURM_ENGINE ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_NAME=$(get_variable CARME_DB_DEFAULT_NAME ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_NODE=$(get_variable CARME_DB_DEFAULT_NODE ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_HOST=$(get_variable CARME_DB_DEFAULT_HOST ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_PORT=$(get_variable CARME_DB_DEFAULT_PORT ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_USER=$(get_variable CARME_DB_DEFAULT_USER ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_ENGINE=$(get_variable CARME_DB_DEFAULT_ENGINE ${FILE_START_CONFIG})

  [[ -z ${CARME_UID} ]] && die "[install_frontend.sh]: CARME_UID not set."
  [[ -z ${CARME_USER} ]] && die "[install_frontend.sh]: CARME_USER not set."
  [[ -z ${CARME_HOME} ]] && die "[install_frontend.sh]: CARME_HOME not set."
  [[ -z ${CARME_USERS} ]] && die "[install_frontend.sh]: CARME_USERS not set."
  [[ -z ${CARME_GROUP} ]] && die "[install_frontend.sh]: CARME_GROUP not set."
  [[ -z ${CARME_SYSTEM} ]] && die "[install_frontend.sh]: CARME_SYSTEM not set."
  [[ -z ${CARME_TIMEZONE} ]] && die "[install_frontend.sh]: CARME_TIMEZONE not set."
  [[ -z ${CARME_NODE_LIST} ]] && die "[install_frontend.sh]: CARME_NODE_LIST not set."
  [[ -z ${CARME_BACKEND_PORT} ]] && die "[install_frontend.sh]: CARME_BACKEND_PORT not set."
  [[ -z ${CARME_BACKEND_NODE} ]] && die "[install_frontend.sh]: CARME_BACKEND_NODE not set."
  [[ -z ${CARME_FRONTEND_ID} ]] && die "[install_frontend.sh]: CARME_FRONTEND_ID not set."
  [[ -z ${CARME_FRONTEND_URL} ]] && die "[install_frontend.sh]: CARME_FRONTEND_URL not set."
  [[ -z ${CARME_FRONTEND_KEY} ]] && die "[install_frontend.sh]: CARME_FRONTEND_KEY not set."
  [[ -z ${CARME_FRONTEND_PORT} ]] && die "[install_frontend.sh]: CARME_FRONTEND_PORT not set."
  [[ -z ${CARME_FRONTEND_NODE} ]] && die "[install_frontend.sh]: CARME_FRONTEND_NODE not set."
  [[ -z ${CARME_PASSWORD_USER} ]] && die "[install_frontend.sh]: CARME_PASSWORD_USER not set."
  [[ -z ${CARME_PASSWORD_DJANGO} ]] && die "[install_frontend.sh]: CARME_PASSWORD_DJANGO not set."
  [[ -z ${CARME_SLURM_CLUSTER_NAME} ]] && die "[install_frontend.sh]: CARME_SLURM_CLUSTER_NAME not set."
  [[ -z ${CARME_SLURM_PARTITION_NAME} ]] && die "[install_frontend.sh]: CARME_SLURM_PARTITION_NAME not set."
  [[ -z ${CARME_SLURM_ACCELERATOR_TYPE} ]] && die "[install_frontend.sh]: CARME_SLURM_ACCELERATOR_TYPE not set."

  [[ -z ${CARME_DB_SLURM_NAME} ]] && die "[install_frontend.sh]: CARME_DB_SLURM_NAME not set."
  [[ -z ${CARME_DB_SLURM_NODE} ]] && die "[install_frontend.sh]: CARME_DB_SLURM_NODE not set."
  [[ -z ${CARME_DB_SLURM_HOST} ]] && die "[install_frontend.sh]: CARME_DB_SLURM_HOST not set."
  [[ -z ${CARME_DB_SLURM_PORT} ]] && die "[install_frontend.sh]: CARME_DB_SLURM_PORT not set."
  [[ -z ${CARME_DB_SLURM_USER} ]] && die "[install_frontend.sh]: CARME_DB_SLURM_USER not set."
  [[ -z ${CARME_DB_SLURM_ENGINE} ]] && die "[install_frontend.sh]: CARME_DB_SLURM_ENGINE not set."
  [[ -z ${CARME_DB_DEFAULT_NAME} ]] && die "[install_frontend.sh]: CARME_DB_DEFAULT_NAME not set."
  [[ -z ${CARME_DB_DEFAULT_NODE} ]] && die "[install_frontend.sh]: CARME_DB_DEFAULT_NODE not set."
  [[ -z ${CARME_DB_DEFAULT_HOST} ]] && die "[install_frontend.sh]: CARME_DB_DEFAULT_HOST not set."
  [[ -z ${CARME_DB_DEFAULT_PORT} ]] && die "[install_frontend.sh]: CARME_DB_DEFAULT_PORT not set."
  [[ -z ${CARME_DB_DEFAULT_USER} ]] && die "[install_frontend.sh]: CARME_DB_DEFAULT_USER not set."
  [[ -z ${CARME_DB_DEFAULT_ENGINE} ]] && die "[install_frontend.sh]: CARME_DB_DEFAULT_ENGINE not set."

  [[ -z ${CARME_LDAP} ]] && CARME_LDAP="null"
  
else
  die "[install_frontend.sh]: ${FILE_START_CONFIG} not found."
fi

# frontend variables ---------------------------------------------------------------------------
 
## cpu info 
#CPU_NAME=$(lscpu | sed -nr '/Model name/ s/.*:\s*//p' | sed 's/\s*@.*//' | sed 's/([^)]*)//g' | sed 's/CPU//g')
#MAIN_MEM_NODE=$(grep "^MemTotal:" /proc/meminfo | awk '{print int($2/1024)}')
#NUM_CPUS_NODE=$(grep -c ^processor /proc/cpuinfo)  

# projects_accelerators DB: 
# name, type, num_per_node, num_cpus_per_node, main_mem_per_node (in MB), node_name, node_status
ACCELERATOR_LIST=()
for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
  if [[ ${COMPUTE_NODE} == "localhost" ]]; then
    COMPUTE_NODE="$(hostname -s)"
  fi 
  COMPUTE_NODE_DATA=$(scontrol show nodes -o | grep "${COMPUTE_NODE}" | awk '
  {
    for (i = 1; i <= NF; i++) {
      split($i, pair, "=")
      switch (pair[1]) {
      case "NodeName":
        node_name = pair[2]
        break
      case "CPUTot":
        num_cpus_per_node = pair[2]
        break
      case "Gres":
        n = split(pair[2], toks, ":") 
        if (toks[1] == "(null)" ){
          type = "cpu"
          name = toupper(type)
          num_per_node = num_cpus_per_node
        } else {
          if (n != 3) {
            printf "ERROR: unknown gres format: NodeName=%s\n", node_name
            next
          } else {
            type = toks[1]
            name = toupper(toks[2])
            num_per_node = toks[3]
          }
        }
        break
      case "RealMemory":
        main_mem_per_node = pair[2]
        break
      case "State":
        node_status = 0
        if (pair[2] == "IDLE" || pair[2] == "MIX" || pair[2] == "ALLOC") {
          node_status = 1
        }
        break
      }
    }
    print name, type, num_per_node, num_cpus_per_node, main_mem_per_node, node_name, node_status
  }
  ')
  ACCELERATOR_LIST+=("$COMPUTE_NODE_DATA")
done

# projects_resourcetemplate DB:
# name, type, max_jobs, max_nodes_per_job, max_accelerators_per_node, walltime (in days), partition, features
TEMPLATE_NAME=${CARME_GROUP}
TEMPLATE_TYPE="linux" # linux (group) or carme (projects)

LEN=${#ACCELERATOR_LIST[@]}
NUM_ACCS_TOTAL=0
MAX_ACCS_PER_NODE=0
for (( i=0; i<$LEN; i++ )); do
  STR="${ACCELERATOR_LIST[$i]}"
  SUBCOUNT=1
  for VALUE in $STR; do
    if [[ "$SUBCOUNT" -eq 3 ]]; then
      # num_per_node from ACCELERATOR_LIST
      NUM_ACCS_TOTAL=$(($VALUE + $NUM_ACCS_TOTAL))
      if [[ $VALUE > $MAX_ACCS_PER_NODE ]]; then
        MAX_ACCS_PER_NODE=$VALUE
      fi
    fi
    (( SUBCOUNT=SUBCOUNT+1 ))
  done
done
if [[ ${CARME_SYSTEM} == "multi" ]]; then
  if [[ $NUM_ACCS_TOTAL > 10 ]]; then
    NUM_ACCS_TOTAL=10
  fi
fi
TEMPLATE_MAX_JOBS=${NUM_ACCS_TOTAL}
TEMPLATE_MAX_NODES_PER_JOB=${#ACCELERATOR_LIST[@]}
TEMPLATE_MAX_ACCELERATORS_PER_NODE=${MAX_ACCS_PER_NODE}
TEMPLATE_WALLTIME=7
TEMPLATE_PARTITION=${CARME_SLURM_PARTITION_NAME}
TEMPLATE_FEATURES="CPU_system"

# projects_project DB:
# name, type, slug, is_approved, description, description_html, classification, information, date_updated, dated_created, owner_id, department, checked, num, date_approved, date_expired
PROJECT_TYPE="local" # local or remote
PROJECT_NAME="localhost"
PROJECT_SLUG="localhost"
PROJECT_IS_APPROVED=1
PROJECT_DESCRIPTION="Single_user_system"
PROJECT_DESCRIPTION_HTML="<p>Single_user_system</p>"
PROJECT_CLASSIFICATION="local"
PROJECT_INFORMATION="CPU_system"
#PROJECT_OWNER_ID=[[SET IN DATABASE]]
PROJECT_DEPARTMENT="home"
PROJECT_CHECKED=1
PROJECT_NUM="H001"

# projects_image DB:
# name, type, path, information, status, owner
IMAGE_NAME="Base"
IMAGE_TYPE="carme" # carme, nvidia, docker
IMAGE_PATH="/home/carme-container/base.sif"
IMAGE_INFO="base_image"
IMAGE_STATUS=1
IMAGE_OWNER="admin"
IMAGE_BIND="_-B_${CARME_HOME}:${CARME_HOME}"

# projects_flag DB:
# name, type
FLAG_NAME="${CARME_HOME}:${CARME_HOME}"
FLAG_TYPE="bind" # bind or option


# install variables ----------------------------------------------------------------------

PATH_FRONTEND_CONTAINERIMAGE=${PATH_CARME}/Carme-ContainerImages/Carme-Frontend-Container
PATH_SERVER_CONF_APACHE2=${PATH_CARME}/Carme-Frontend/Carme-Server-Conf/apache2
PATH_SERVER_CONF=${PATH_CARME}/Carme-Frontend/Carme-Server-Conf
PATH_SINGULARITY=${PATH_CARME}/Carme-Vendors/singularity/bin
PATH_SYSTEMD=/etc/systemd/system
PATH_CONFIG=/etc/carme

# files
FILE_FRONTEND_CONTAINERIMAGE=${PATH_FRONTEND_CONTAINERIMAGE}/frontend.sif
FILE_FRONTEND_SYSTEMD=${PATH_SYSTEMD}/carme-frontend.service
FILE_FRONTEND_CONFIG=${PATH_CONFIG}/CarmeConfig.frontend
FILE_SINGULARITY=${PATH_SINGULARITY}/singularity
FILE_SERVER_CONF_HOSTS=${PATH_SERVER_CONF}/hosts
FILE_SERVER_CONF_APACHE2_PORTS=${PATH_SERVER_CONF_APACHE2}/ports.conf
FILE_SERVER_CONF_APACHE2_002GPU=${PATH_SERVER_CONF_APACHE2}/002-gpu.conf
FILE_SERVER_CONF_APACHE2_APACHE2=${PATH_SERVER_CONF_APACHE2}/apache2.conf


# installation starts ---------------------------------------------------------------------
log "starting frontend installation..."

# verify singularity ----------------------------------------------------------------------
if ! command -v "${FILE_SINGULARITY}" >/dev/null 2>&1; then
    die "[install_frontend.sh]: Singularity is not installed in ${PATH_SINGULARITY}."
fi

# unset proxy if exists -------------------------------------------------------------------
log "unsetting proxy if exists..."
if [[ $http_proxy != "" || $https_proxy != "" ]]; then
    http_proxy=""
    https_proxy=""
fi

# create config ---------------------------------------------------------------------------
log "creating frontend config..."

mkdir -p ${PATH_CONFIG}
[[ -f "${FILE_FRONTEND_CONFIG}" ]] && mv "${FILE_FRONTEND_CONFIG}" "${FILE_FRONTEND_CONFIG}.bak"
touch ${FILE_FRONTEND_CONFIG}
cat << EOF >> ${FILE_FRONTEND_CONFIG}
#------------------------------------------------------------------------------------------
# CarmeConfig.frontend
# This file is generated automatically via ${PATH_CARME}/Carme-Install/install_frontend.sh
#------------------------------------------------------------------------------------------ 
#
# GENERAL ---------------------------------------------------------------------------------
CARME_URL="${CARME_FRONTEND_URL}"
CARME_VERSION="${CARME_VERSION}"
CARME_TIMEZONE="${CARME_TIMEZONE}"
#
# SECURITY --------------------------------------------------------------------------------
CARME_KEY="${CARME_FRONTEND_KEY}"
CARME_PASSWORD_DJANGO="${CARME_PASSWORD_DJANGO}"
#
# USER ------------------------------------------------------------------------------------
CARME_UID="${CARME_UID}"
CARME_HOME="${CARME_HOME}"
CARME_LDAP="${CARME_LDAP}"
CARME_USER="${CARME_USER}"
CARME_USERS="${CARME_USERS}"
CARME_GROUP="${CARME_GROUP}"
#
# CLUSTER ---------------------------------------------------------------------------------
CARME_NODE_LIST="${CARME_NODE_LIST}"
CARME_ACCELERATOR_NUM="${CARME_ACCELERATOR_NUM}"
CARME_ACCELERATOR_SPECS="${CARME_ACCELERATOR_SPECS}"
CARME_SLURM_CLUSTER_NAME="${CARME_SLURM_CLUSTER_NAME}"
#
# DATABASE --------------------------------------------------------------------------------
CARME_DB_SLURM_NAME="${CARME_DB_SLURM_NAME}"
CARME_DB_SLURM_NODE="${CARME_DB_SLURM_NODE}"
CARME_DB_SLURM_HOST="${CARME_DB_SLURM_HOST}"
CARME_DB_SLURM_PORT="${CARME_DB_SLURM_PORT}"
CARME_DB_SLURM_USER="${CARME_DB_DEFAULT_USER}"
CARME_DB_SLURM_ENGINE="${CARME_DB_SLURM_ENGINE}"
CARME_DB_DEFAULT_NAME="${CARME_DB_DEFAULT_NAME}"
CARME_DB_DEFAULT_NODE="${CARME_DB_DEFAULT_NODE}"
CARME_DB_DEFAULT_HOST="${CARME_DB_DEFAULT_HOST}"
CARME_DB_DEFAULT_PORT="${CARME_DB_DEFAULT_PORT}"
CARME_DB_DEFAULT_USER="${CARME_DB_DEFAULT_USER}"
CARME_DB_DEFAULT_ENGINE="${CARME_DB_DEFAULT_ENGINE}"
#
# FRONTEND --------------------------------------------------------------------------------
CARME_FRONTEND_ID="${CARME_FRONTEND_ID}"
#
# BACKEND ---------------------------------------------------------------------------------
CARME_BACKEND_PORT="${CARME_BACKEND_PORT}"
CARME_BACKEND_NODE="${CARME_BACKEND_NODE}"
#
# FRAUNHOFER ------------------------------------------------------------------------------
CARME_FRONTEND_LINK_DISCLAIMER="https://www.itwm.fraunhofer.de/de/impressum.html"
CARME_FRONTEND_LINK_PRIVACY="https://www.itwm.fraunhofer.de/de/datenschutzerklaerung.html"
EOF

# check if www-data user and group exist
if id -u www-data &>/dev/null; then
  WWW_DATA_USER="true"
else
  WWW_DATA_USER="false"
fi

if id -g www-data &>/dev/null; then
  WWW_DATA_GROUP="true"
else
  WWW_DATA_GROUP="false"
fi

if [[ "${WWW_DATA_USER}" == "true" && "${WWW_DATA_GROUP}" == "true" ]]; then
  # change ownership of CarmeConfig.frontend  
  chown www-data:www-data "${FILE_FRONTEND_CONFIG}"

  # change permissions of new CarmeConfig.frontend
  chmod 600 "${FILE_FRONTEND_CONFIG}" || die "[install_frontend.sh]: cannot change file permissions of ${FILE_FRONTEND_CONFIG}."
else
  if [[ "${WWW_DATA_USER}" == "false" && "${WWW_DATA_GROUP}" == "false" ]]; then
    die "[install_frontend.sh]: www-data user and group do not exist in your system."
  elif [[ "${WWW_DATA_USER}" == "false" ]]; then
    die "[install_frontend.sh]: www-data user does not exist in your system. Please contact us."
  elif [[ "${WWW_DATA_GROUP}" == "false" ]]; then
    die "[install_frontend.sh]: www-data group does not exist in your system. Please contact us."
  fi
fi

# create frontend server conf -------------------------------------------------------------
log "creating server config..."

mkdir -p ${PATH_SERVER_CONF}
mkdir -p ${PATH_SERVER_CONF_APACHE2}

[[ -f "${FILE_SERVER_CONF_HOSTS}" ]] && rm "${FILE_SERVER_CONF_HOSTS}" 
[[ -f "${FILE_SERVER_CONF_APACHE2_PORTS}" ]] && rm "${FILE_SERVER_CONF_APACHE2_PORTS}"
[[ -f "${FILE_SERVER_CONF_APACHE2_002GPU}" ]] && rm "${FILE_SERVER_CONF_APACHE2_002GPU}"
[[ -f "${FILE_SERVER_CONF_APACHE2_APACHE2}" ]] && rm "${FILE_SERVER_CONF_APACHE2_APACHE2}"

touch ${FILE_SERVER_CONF_HOSTS}
touch ${FILE_SERVER_CONF_APACHE2_PORTS}
touch ${FILE_SERVER_CONF_APACHE2_002GPU}
touch ${FILE_SERVER_CONF_APACHE2_APACHE2}

cat << EOF >> ${FILE_SERVER_CONF_HOSTS}
127.0.0.1	localhost 

## The following lines are desirable for IPv6 capable hosts
#::1     localhost ip6-localhost ip6-loopback
#ff02::1 ip6-allnodes
#ff02::2 ip6-allrouters
EOF

cat << EOF >> ${FILE_SERVER_CONF_APACHE2_PORTS}
Listen ${CARME_FRONTEND_PORT}
EOF

cat << EOF >> ${FILE_SERVER_CONF_APACHE2_002GPU}
<VirtualHost *:${CARME_FRONTEND_PORT}> 
 ServerName carme.ai
 DocumentRoot ${PATH_CARME}/Carme-Frontend/Carme-Django/webfrontend/ 
 WSGIScriptAlias / ${PATH_CARME}/Carme-Frontend/Carme-Django/webfrontend/scripts/wsgi.py  
 
 # adjust the following line to match your Python path 
 WSGIDaemonProcess carme.ai processes=2 threads=15 display-name=%{GROUP}  
 WSGIProcessGroup carme.ai
 WSGIApplicationGroup %{GLOBAL}
 
 <directory ${PATH_CARME}/Carme-Frontend/Carme-Django/webfrontend/>
   AllowOverride all 
   Require all granted 
   Options FollowSymlinks 
 </directory> 
 
 Alias /static/ ${PATH_CARME}/Carme-Frontend/Carme-Django/static/
 
 <Directory ${PATH_CARME}/Carme-Frontend/Carme-Django/static/>
  Require all granted 
 </Directory> 
</VirtualHost>
EOF

cat << EOF >> ${FILE_SERVER_CONF_APACHE2_APACHE2}

# Runtime ----------------------------------------------------------------
DefaultRuntimeDir /opt/apache2-run
PidFile /opt/apache2-run/apache2.pid
#-------------------------------------------------------------------------

# Timing -----------------------------------------------------------------
MaxKeepAliveRequests 100
KeepAliveTimeout 5
KeepAlive On
Timeout 300
#-------------------------------------------------------------------------

# Owner ------------------------------------------------------------------
User $(echo '${APACHE_RUN_USER}')
Group $(echo '${APACHE_RUN_GROUP}')
#-------------------------------------------------------------------------

# Include ----------------------------------------------------------------
IncludeOptional mods-enabled/*.load
IncludeOptional mods-enabled/*.conf
IncludeOptional conf-enabled/*.conf
IncludeOptional sites-enabled/*.conf
Include ports.conf
#-------------------------------------------------------------------------

# Expiration -------------------------------------------------------------
ExpiresActive On
ExpiresByType image/jpg "access plus 2 hours"
ExpiresByType image/png "access plus 2 hours"
#-------------------------------------------------------------------------

# Security ---------------------------------------------------------------
AccessFileName .htaccess

<Directory />
	Options FollowSymLinks
	AllowOverride None
	Require all denied
</Directory>
<Directory /usr/share>
	AllowOverride None
	Require all granted
</Directory>
<Directory /var/www/>
	Options Indexes FollowSymLinks
	AllowOverride None
	Require all granted
</Directory>
<FilesMatch "^\.ht">
	Require all denied
</FilesMatch>
#------------------------------------------------------------------------

# Logs ------------------------------------------------------------------
LogLevel warn
HostnameLookups Off
ErrorLog $(echo '${APACHE_LOG_DIR}')/error.log

LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
LogFormat "%h %l %u %t \"%r\" %>s %O" common
LogFormat "%{Referer}i -> %U" referer
LogFormat "%{User-agent}i" agent
#------------------------------------------------------------------------

# Server ----------------------------------------------------------------
ServerName ${CARME_FRONTEND_NODE}
ServerSignature Off
ServerTokens Prod
#------------------------------------------------------------------------
EOF

# create frontend service -----------------------------------------------------------------
log "creating frontend service..."

if [[ -f ${FILE_FRONTEND_SYSTEMD} ]]; then
    systemctl stop carme-frontend.service
    rm ${FILE_FRONTEND_SYSTEMD}
fi
touch ${FILE_FRONTEND_SYSTEMD}

cat << EOF >> ${FILE_FRONTEND_SYSTEMD}
[Unit]
Description=Carme Frontend
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=forking
Environment=SINGULARITYENV_APACHE_STARTED_BY_SYSTEMD=1
Environment=SINGULARITYENV_APACHE_LOG_DIR=/opt/Carme-Apache-Logs
ExecStartPre=-/usr/bin/mkdir -p /var/run/carme/frontend
ExecStartPre=-/usr/bin/mkdir -p /var/log/carme/apache
ExecStartPre=-/usr/bin/chown -R www-data:www-data /var/log/carme/apache
ExecStart=${FILE_SINGULARITY} exec -B "/etc/carme/CarmeConfig.frontend" -B "/var/log/carme/apache:/opt/Carme-Apache-Logs" -B "/var/run/carme/frontend:/opt/apache2-run" -B "/var/run" "${PATH_CARME}/Carme-ContainerImages/Carme-Frontend-Container/frontend.sif" /usr/sbin/apache2ctl start
ExecStop=${FILE_SINGULARITY} exec -B "/etc/carme/CarmeConfig.frontend" -B "/var/log/carme/apache:/opt/Carme-Apache-Logs" -B "/var/run/carme/frontend:/opt/apache2-run" -B "/var/run" "${PATH_CARME}/Carme-ContainerImages/Carme-Frontend-Container/frontend.sif" /usr/sbin/apache2ctl stop
PIDFile=/var/run/carme/frontend/apache2.pid
RestartSec=30
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# create frontend directories -------------------------------------------------------------
log "creating frontend directories..."

mkdir -p /var/run/carme/frontend
mkdir -p /var/log/carme/apache
chown -R www-data:www-data /var/log/carme/apache

# build frontend image --------------------------------------------------------------------
log "building frontend image..."

if [[ $(installed "debootstrap" "single") == "not installed" ]]; then
  apt install debootstrap -y
fi

log "initializing build (please wait)..."
${FILE_SINGULARITY} build "/tmp/frontend.sif" "${PATH_FRONTEND_CONTAINERIMAGE}/frontend.recipe"
[[ -f "${PATH_FRONTEND_CONTAINERIMAGE}/frontend.sif" ]] && mv "${PATH_FRONTEND_CONTAINERIMAGE}/frontend.sif" "${PATH_FRONTEND_CONTAINERIMAGE}/frontend.sif.bak"
mv "/tmp/frontend.sif" "${PATH_FRONTEND_CONTAINERIMAGE}/frontend.sif"

# migrate frontend tables -----------------------------------------------------------------
log "migrating frontend tables..."

${FILE_SINGULARITY} exec --writable-tmpfs -B "/etc/carme/CarmeConfig.frontend" -B "/var/log/carme/apache:/opt/Carme-Apache-Logs" -B "/var/run/carme/frontend:/opt/apache2-run" -B "/var/run" -B "${PATH_CARME}/Carme-Frontend" "${PATH_CARME}/Carme-ContainerImages/Carme-Frontend-Container/frontend.sif" python3 ${PATH_CARME}/Carme-Frontend/Carme-Django/webfrontend/manage.py makemigrations
${FILE_SINGULARITY} exec --writable-tmpfs -B "/etc/carme/CarmeConfig.frontend" -B "/var/log/carme/apache:/opt/Carme-Apache-Logs" -B "/var/run/carme/frontend:/opt/apache2-run" -B "/var/run" -B "${PATH_CARME}/Carme-Frontend" "${PATH_CARME}/Carme-ContainerImages/Carme-Frontend-Container/frontend.sif" python3 ${PATH_CARME}/Carme-Frontend/Carme-Django/webfrontend/manage.py migrate

# start frontend service ------------------------------------------------------------------
log "starting frontend service..."

systemctl is-active --quiet carme-frontend && is_active=true || is_active=false
systemctl is-enabled --quiet carme-frontend && is_enabled=true || is_enabled=false

if [[ ${is_active} = false ]]; then
  systemctl start carme-frontend.service
  systemctl is-active --quiet carme-frontend || die "[install_frontend.sh]: carme-frontend.service is not running."
  if [[ ${is_enabled} = false ]]; then
    systemctl enable carme-frontend.service
    systemctl is-enabled --quiet carme-frontend || die "[install_frontend.sh]: carme-frontend.service is not enabled."
  fi
else
  systemctl restart carme-frontend.service
  systemctl is-active --quiet carme-frontend || die "[install_frontend.sh]: carme-frontend.service is not running."
  if [[ ${is_enabled} = false ]]; then
    systemctl enable carme-frontend.service
    systemctl is-enabled --quiet carme-frontend || die "[install_frontend.sh]: carme-frontend.service is not enabled."
  fi
fi

# set database password ---------------------------------------------------------------------
export MYSQL_PWD=${CARME_PASSWORD_DJANGO}

# clean tables ------------------------------------------------------------------------------
log "cleaning tables..."

# primary tables
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table auth_user"
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_project"
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_resourcetemplate"
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_accelerator"
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_image"
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_flag"

# secondary tables 
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_projectmember"
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_projecthastemplate"
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_templatehasaccelerator"
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_templatehasimage"
mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_imagehasflag"


# filling tables -----------------------------------------------------------------------------
log "filling tables..."

#########################
###  primary tables  ####
#########################

# auth_user
mysql --user=django webfrontend -e "INSERT INTO auth_user (\`username\`, \`password\`, \`first_name\`, \`last_name\`, \`email\`, \`is_superuser\`, \`is_staff\`, \`is_active\`, \`date_joined\`) VALUES ('$CARME_USER', '$CARME_PASSWORD_USER', '', '', '', 1, 1, 1, curdate())"
PROJECT_OWNER_ID=$(mysql --user=django webfrontend -se "SELECT id FROM auth_user where username='$CARME_USER'")

# projects_project
mysql --user=django webfrontend -e "INSERT INTO projects_project (\`name\`, \`type\`, \`slug\`, \`is_approved\`, \`description\`, \`description_html\`, \`classification\`, \`information\`, \`date_created\`, \`owner_id\`, \`department\`, \`checked\`, \`num\`) VALUES ('$PROJECT_NAME', '$PROJECT_TYPE', '$PROJECT_SLUG', $PROJECT_IS_APPROVED, '${PROJECT_DESCRIPTION//_/ }', '${PROJECT_DESCRIPTION_HTML//_/ }', '$PROJECT_CLASSIFICATION', '${PROJECT_INFORMATION//_/ }', curdate(), $PROJECT_OWNER_ID, '$PROJECT_DEPARTMENT', $PROJECT_CHECKED, '$PROJECT_NUM')"
PROJECT_ID=$(mysql --user=django webfrontend -se "SELECT id FROM projects_project where owner_id='$PROJECT_OWNER_ID'")

# projects_resourcetemplate
mysql --user=django webfrontend -e "INSERT INTO projects_resourcetemplate (\`name\`, \`type\`, \`maxjobs\`, \`maxnodes_per_job\`, \`maxaccels_per_node\`, \`walltime\`, \`partition\`, \`features\`) VALUES ('$TEMPLATE_NAME', '$TEMPLATE_TYPE', $TEMPLATE_MAX_JOBS, $TEMPLATE_MAX_NODES_PER_JOB, $TEMPLATE_MAX_ACCELERATORS_PER_NODE, $TEMPLATE_WALLTIME, '$TEMPLATE_PARTITION', '${TEMPLATE_FEATURES//_/ }')"
TEMPLATE_ID=$(mysql --user=django webfrontend -se "SELECT id FROM projects_resourcetemplate where name='$TEMPLATE_NAME'")

# projects_accelerator
# e.g.:
#ACCELERATOR_LIST=('name_1 type_1 num_per_node_1 num_cpus_per_node_1 main_mem_per_node_in_MB_1 node_name_1 node_status_1'\
#                  'name_2 type_2 num_per_node_2 num_cpus_per_node_2 main_mem_per_node_in_MB_2 node_name_2 node_status_2'\
#                                                           ...                                                          \ 
#                  'CPU    cpu    8              8                   9000                      carme01     1            '\
#                  'A100   gpu    4              40                  10000                     carme02     1            '\
#                  'TITAN  gpu    4              20                  10000                     carme03     0            ')

len=${#ACCELERATOR_LIST[@]}
for (( i=0; i<$len; i++ )); do
        str="${ACCELERATOR_LIST[$i]}"
        subcount=1
        for value in $str; do
          if [[ "$subcount" -eq 1 ]]; then
                tmp_name=$value
          fi
          if [[ "$subcount" -eq 2 ]]; then
                tmp_type=$value
          fi
          if [[ "$subcount" -eq 3 ]]; then
                tmp_num_per_node=$value
          fi
          if [[ "$subcount" -eq 4 ]]; then
                tmp_num_cpus_per_node=$value
          fi
          if [[ "$subcount" -eq 5 ]]; then
                tmp_main_mem_per_node=$value
          fi
          if [[ "$subcount" -eq 6 ]]; then
                tmp_node_name=$value
          fi
          if [[ "$subcount" -eq 7 ]]; then
                tmp_node_status=$value
          fi
          (( subcount=subcount+1 ))
        done
	# insert values in table
	tmp_name="${tmp_name//_/ }"
        mysql --user=django webfrontend -e "INSERT INTO projects_accelerator (\`name\`, \`type\`, \`num_per_node\`, \`num_cpus_per_node\`, \`main_mem_per_node\`, \`node_name\`, \`node_status\`) VALUES ('$tmp_name', '$tmp_type', $tmp_num_per_node, $tmp_num_cpus_per_node, $tmp_main_mem_per_node, '$tmp_node_name', $tmp_node_status)"

done

#mysql --user=django webfrontend -e "INSERT INTO projects_accelerator (\`name\`, \`type\`, \`num_per_node\`, \`num_cpus_per_node\`, \`main_mem_per_node\`, \`node_name\`, \`node_status\`) VALUES ('${ACCELERATOR_NAME//_/ }', '$ACCELERATOR_TYPE', $ACCELERATOR_NUM_PER_NODE, $ACCELERATOR_NUM_CPUS_PER_NODE, $ACCELERATOR_MAIN_MEM_PER_NODE, '$ACCELERATOR_NODE_NAME', $ACCELERATOR_NODE_STATUS)"
#ACCELERATOR_ID=$(mysql --user=django webfrontend -se "SELECT id FROM projects_accelerator where name='${ACCELERATOR_NAME//_/ }'")

# projects_image
mysql --user=django webfrontend -e "INSERT INTO projects_image (\`name\`, \`type\`, \`path\`, \`information\`, \`status\`, \`owner\`, \`bind\`) VALUES ('$IMAGE_NAME', '$IMAGE_TYPE', '$IMAGE_PATH', '${IMAGE_INFO//_/ }', '$IMAGE_STATUS', '$IMAGE_OWNER', '$IMAGE_BIND')"
IMAGE_ID=$(mysql --user=django webfrontend -se "SELECT id FROM projects_image where name='$IMAGE_NAME'")

# projects_flag
mysql --user=django webfrontend -e "INSERT INTO projects_flag (\`name\`, \`type\`) VALUES ('$FLAG_NAME', '$FLAG_TYPE')"
FLAG_ID=$(mysql --user=django webfrontend -se "SELECT id FROM projects_flag where name='${FLAG_NAME}'")

#########################
### secondary tables ####
#########################

# projects_projectmember 
mysql --user=django webfrontend -e "INSERT INTO projects_projectmember (\`status\`, \`is_manager\`, \`is_approved_by_manager\`, \`is_approved_by_admin\`, \`project_id\`, \`user_id\`) VALUES ('accepted', 1, 1, 1, ${PROJECT_ID}, ${PROJECT_OWNER_ID})"

# projects_projecthastemplate
mysql --user=django webfrontend -e "INSERT INTO projects_projecthastemplate (\`project_id\`, \`template_id\`) VALUES (${PROJECT_ID}, ${TEMPLATE_ID})"

# projects_templatehasaccelerator
len=${#ACCELERATOR_LIST[@]}
for (( i=0; i<$len; i++ )); do
  (( ACCELERATOR_ID=$i+1 ))
  mysql --user=django webfrontend -e "INSERT INTO projects_templatehasaccelerator (\`accelerator_id\`, \`resourcetemplate_id\`) VALUES (${ACCELERATOR_ID}, ${TEMPLATE_ID})"
done

# projects_templatehasimage
mysql --user=django webfrontend -e "INSERT INTO projects_templatehasimage (\`image_id\`, \`resourcetemplate_id\`) VALUES (${IMAGE_ID}, ${TEMPLATE_ID})"

# projects_imagehasflag
mysql --user=django webfrontend -e "INSERT INTO projects_imagehasflag (\`image_id\`, \`flag_id\`) VALUES (${IMAGE_ID}, ${FLAG_ID})"

log "frontend is successfully installed."
