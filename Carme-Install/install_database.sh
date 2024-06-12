#!/bin/bash
#-----------------------------------------------------------------------------------------#
#------------------------------ Database installation ------------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic funtions --------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then

  CARME_DB=$(get_variable CARME_DB ${FILE_START_CONFIG})
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_DB_SERVER=$(get_variable CARME_DB_SERVER ${FILE_START_CONFIG})
  CARME_DB_SLURM_NAME=$(get_variable CARME_DB_SLURM_NAME ${FILE_START_CONFIG})
  CARME_DB_SLURM_USER=$(get_variable CARME_DB_SLURM_USER ${FILE_START_CONFIG})
  CARME_PASSWORD_MYSQL=$(get_variable CARME_PASSWORD_MYSQL ${FILE_START_CONFIG})
  CARME_PASSWORD_SLURM=$(get_variable CARME_PASSWORD_SLURM ${FILE_START_CONFIG})
  CARME_PASSWORD_DJANGO=$(get_variable CARME_PASSWORD_DJANGO ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_PORT=$(get_variable CARME_DB_DEFAULT_PORT ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_NAME=$(get_variable CARME_DB_DEFAULT_NAME ${FILE_START_CONFIG})
  CARME_DB_DEFAULT_USER=$(get_variable CARME_DB_DEFAULT_USER ${FILE_START_CONFIG})

  [[ -z ${CARME_DB} ]] && die "[install_database.sh]: CARME_DB not set."
  [[ -z ${CARME_SYSTEM} ]] && die "[install_database.sh]: CARME_SYSTEM not set."
  [[ -z ${CARME_DB_SERVER} ]] && die "[install_database.sh]: CARME_DB_SERVER not set."
  [[ -z ${CARME_DB_SLURM_NAME} ]] && die "[install_database.sh]: CARME_DB_SLURM_NAME not set."
  [[ -z ${CARME_DB_SLURM_USER} ]] && die "[install_database.sh]: CARME_DB_SLURM_USER not set."
  [[ -z ${CARME_PASSWORD_MYSQL} ]] && die "[install_database.sh]: CARME_PASSWORD_MYSQL not set."
  [[ -z ${CARME_PASSWORD_SLURM} ]] && die "[install_database.sh]: CARME_PASSWORD_SLURM not set."
  [[ -z ${CARME_PASSWORD_DJANGO} ]] && die "[install_database.sh]: CARME_PASSWORD_DJANGO not set."
  [[ -z ${CARME_DB_DEFAULT_PORT} ]] && die "[install_database.sh]: CARME_DB_DEFAULT_PORT not set."
  [[ -z ${CARME_DB_DEFAULT_NAME} ]] && die "[install_database.sh]: CARME_DB_DEFAULT_NAME not set."
  [[ -z ${CARME_DB_DEFAULT_USER} ]] && die "[install_database.sh]: CARME_DB_DEFAULT_USER not set."

else
  die "[install_database.sh]: ${FILE_START_CONFIG} not found."
fi

# installation / configuration starts -----------------------------------------------------
if [[ ${CARME_DB} == "yes" ]]; then
  log "starting database installation..."
elif [[ ${CARME_DB} == "no" ]]; then
  log "starting database configuration..."
else
  die "[install_mysql.sh]: CARME_DB=${CARME_DB} in CarmeConfig.start is not set properly. It must be \`yes\` or \`no\`."
fi

# set database server ----------------------------------------------------------------------
log "setting database server..."

if [[ ${CARME_DB_SERVER} == "mariadb" ]]; then
  DB_SERVER="mariadb-server"
  DB_SERVICE="mariadb"
elif [[ ${CARME_DB_SERVER} == "mysql" ]]; then 
  DB_SERVER="mysql-server-8.0"
  DB_SERVICE="mysql"
else
  die "[install_mysql.sh]: CARME_DB_SERVER=${CARME_DB_SERVER} in CarmeConfig.start is not set properly. It must be \`mariadb\` or \`mysql\`."
fi

# install database server ------------------------------------------------------------------
if [[ ${CARME_DB} == "yes" ]]; then  
  if [[ $(installed "${DB_SERVER}" "single") == "installed" ]]; then
    log "${DB_SERVER} is already installed..."
    
    MESSAGE_DB_START="Do you want to use the already existing ${DB_SERVICE}? Type No if you prefer to remove it [y/N]:"
    read -rp "${MESSAGE_DB_START} " REPLY
    if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
      systemctl is-active --quiet ${DB_SERVICE} && log "${DB_SERVICE}.service is running." || systemctl start ${DB_SERVICE}.service
      systemctl is-active --quiet ${DB_SERVICE} || die "[install_mysql.sh]: ${DB_SERVICE}.service is not running. Your existing ${DB_SERVICE} won't start. Try removing it."
    elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
      MESSAGE_DB_REMOVE="Are you sure that you want to remove the already existing ${DB_SERVICE} (all databases will be lost)? [y/N]:"
      read -rp "${MESSAGE_DB_REMOVE} " REPLY
      if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
        log "removing ${DB_SERVER}..."
	apt-get remove --purge ${DB_SERVICE}-server* -y
        apt-get remove --purge mysql-\* -y
        apt -y autoremove
        apt autoclean
        apt clean all
        rm -rf /etc/mysql/ /var/lib/mysql/ /var/log/mysql
        apt clean

	log "reinstalling ${DB_SERVER}..."
        debconf-set-selections <<< "${DB_SERVER} mysql-server/root_password password ${CARME_PASSWORD_MYSQL}"
        debconf-set-selections <<< "${DB_SERVER} mysql-server/root_password_again password ${CARME_PASSWORD_MYSQL}"
        apt-get install ${DB_SERVER} -y
      elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
        die "[install_mysql.sh]: You have cancelled the request. Please try again."
      else
        die "[install_mysql.sh]: Your answer was not yes or no. Please try again."
      fi
    fi 
  else
    log "installing ${DB_SERVER}..."
    
    debconf-set-selections <<< "${DB_SERVER} mysql-server/root_password password $CARME_PASSWORD_MYSQL"
    debconf-set-selections <<< "${DB_SERVER} mysql-server/root_password_again password $CARME_PASSWORD_MYSQL"
    apt-get install ${DB_SERVER} -y
    apt-get autoremove -y
    apt-get clean
  fi

elif  [[ ${CARME_DB} == "no" ]]; then
  if ! [[ $(installed "${DB_SERVER}" "single") == "installed" ]]; then
    die "[install_mysql.sh]: ${DB_SERVER} is not installed. To install it, consider CARME_DB=yes in CarmeConfig.start and try again."
  fi
fi

# configure database server ----------------------------------------------------------------
log "configuring ${DB_SERVER}..."

export MYSQL_PWD=${CARME_PASSWORD_MYSQL}
mysql -uroot -e "CREATE DATABASE IF NOT EXISTS ${CARME_DB_SLURM_NAME};
                 CREATE DATABASE IF NOT EXISTS ${CARME_DB_DEFAULT_NAME};
                 CREATE USER IF NOT EXISTS '${CARME_DB_SLURM_USER}'@'localhost' IDENTIFIED BY '$CARME_PASSWORD_SLURM';
                 CREATE USER IF NOT EXISTS '${CARME_DB_DEFAULT_USER}'@'localhost' IDENTIFIED BY '$CARME_PASSWORD_DJANGO';
                 GRANT ALL PRIVILEGES ON ${CARME_DB_SLURM_NAME}.* TO '${CARME_DB_SLURM_USER}'@'localhost';
                 GRANT ALL PRIVILEGES ON ${CARME_DB_SLURM_NAME}.* to '${CARME_DB_DEFAULT_USER}'@'localhost';
                 GRANT ALL PRIVILEGES ON ${CARME_DB_DEFAULT_NAME}.* to '${CARME_DB_DEFAULT_USER}'@'localhost';
		 ALTER USER 'root'@'localhost' IDENTIFIED BY '${CARME_PASSWORD_MYSQL}';
                 FLUSH PRIVILEGES;";

# configure my.cnf: memory restriction -----------------------------------------------------
log "configuring my.cnf..."

systemctl stop ${DB_SERVICE}.service

MYCNF="
\[mysqld\]
innodb_buffer_pool_size=4096M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
max_allowed_packet=16M
port=${CARME_DB_DEFAULT_PORT}"

readarray -t <<< $MYCNF

NOT_FOUND_COUNTER=0
for STRING in "${MAPFILE[@]}"; do
  if ! grep -q "^$STRING$" /etc/mysql/my.cnf; then
    NOT_FOUND_COUNTER=$((NOT_FOUND_COUNTER+1))
  fi
done

if [[ ${NOT_FOUND_COUNTER} == 6 ]]; then
  cat << EOF >> /etc/mysql/my.cnf

# carme-innodb 
[mysqld]
innodb_buffer_pool_size=4096M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
max_allowed_packet=16M
port=${CARME_DB_DEFAULT_PORT}
EOF

elif [[ ${NOT_FOUND_COUNTER} == 0 ]]; then
  true
else
  die "[install_mysql.sh]: ${NOT_FOUND_COUNTER}. To proceed, you need to add the following to \`/etc/mysql/my.cnf\`
  
[mysqld]
innodb_buffer_pool_size=4096M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
max_allowed_packet=16M
port=${CARME_DB_DEFAULT_PORT}"
fi


# configure mysqld.cnf: localhost restriction ---------------------------------------------
if [[ ${CARME_SYSTEM} == "multi" ]]; then
  if [[ ${CARME_DB_SERVER} == "mysql" ]]; then
    log "configuring mysqld.cnf..."

    if grep -q -n "^bind-address" "/etc/mysql/mysql.conf.d/mysqld.cnf"; then
      sed -i "s/^bind-address/#bind-address/g" "/etc/mysql/mysql.conf.d/mysqld.cnf"
    fi
    if grep -q -n "^mysqlx-bind-address" "/etc/mysql/mysql.conf.d/mysqld.cnf"; then
      sed -i "s/^mysqlx-bind-address/#mysqlx-bind-address/g" "/etc/mysql/mysql.conf.d/mysqld.cnf"
    fi
  elif [[ ${CARME_DB_SERVER} == "mariadb" ]]; then
    log "configuring 50-server.cnf..."

    if grep -q -n "^bind-address" "/etc/mysql/mariadb.conf.d/50-server.cnf"; then
      sed -i "s/^bind-address/#bind-address/g" "/etc/mysql/mariadb.conf.d/50-server.cnf"
    fi
  fi
fi

# remove binlogs --------------------------------------------------------------------------
if [[ $DB_SERVICE == "mysql" ]]; then
  log "removing binlogs..."

  BINLOGS=( /var/lib/mysql/binlog* )
  if ! [[ ${BINLOGS} = "/var/lib/mysql/binlog*" ]]; then
    mv /var/lib/mysql/binlog* /tmp
  fi
fi

# start the service -----------------------------------------------------------------------
log "starting ${DB_SERVICE}.service..."

systemctl start ${DB_SERVICE}.service
if [[ ${CARME_DB} == "yes" ]]; then
  systemctl is-active --quiet ${DB_SERVICE} && log "${DB_SERVICE} succesfully installed." || die "[install_mysql.sh]: ${DB_SERVICE}.service is not running."
else
  systemctl is-active --quiet ${DB_SERVICE} && log "${DB_SERVICE} succesfully configured." || die "[install_mysql.sh]: ${DB_SERVICE}.service is not running."	
fi
