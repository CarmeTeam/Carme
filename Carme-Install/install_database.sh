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

# unset proxy -----------------------------------------------------------------------------
if [[ $http_proxy != "" || $https_proxy != "" ]]; then
    http_proxy=""
    https_proxy=""
fi

# config variables ------------------------------------------------------------------------
FILE_START_CONFIG="${PATH_CARME}/CarmeConfig.start"

if [[ -f ${FILE_START_CONFIG} ]]; then

  SYSTEM_DIST=$(get_variable SYSTEM_DIST ${FILE_START_CONFIG})

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

  [[ -z ${SYSTEM_DIST} ]] && die "[install_database.sh]: SYSTEM_DIST not set."

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
  if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
    DB_SERVER="mysql-server-8.0"
    DB_SERVICE="mysql"
  elif [[ $SYSTEM_DIST == "rocky" ]]; then
    DB_SERVER="mysql-server"
    DB_SERVICE="mysqld"
  fi
else
  die "[install_mysql.sh]: CARME_DB_SERVER=${CARME_DB_SERVER} in CarmeConfig.start is not set properly. It must be \`mariadb\` or \`mysql\`."
fi

# install database server ------------------------------------------------------------------
if [[ ${CARME_DB} == "yes" ]]; then  
  if [[ $(installed "${DB_SERVER}" "single") == "installed" ]]; then
    log "${DB_SERVER} is already installed..."
    
    MESSAGE_DB_START="Do you want to use the already existing ${DB_SERVICE}? Type No if you prefer to remove it [Y/n]:"
    read -rp "${MESSAGE_DB_START} " REPLY
    if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
      systemctl is-active --quiet ${DB_SERVICE} && log "${DB_SERVICE}.service is running." || systemctl start ${DB_SERVICE}.service
      systemctl is-active --quiet ${DB_SERVICE} || die "[install_mysql.sh]: ${DB_SERVICE}.service is not running. Your existing ${DB_SERVICE} won't start. Try removing it."
    elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
      MESSAGE_DB_REMOVE="Are you sure that you want to remove the already existing ${DB_SERVICE} (all databases will be lost)? [y/n]:"
      read -rp "${MESSAGE_DB_REMOVE} " REPLY
      if [[ $REPLY =~ ^[Yy]$ || $REPLY == "Yes" || $REPLY == "yes" ]]; then
        log "removing ${DB_SERVER}..."
	remove_packages ${DB_SERVICE}-server*
        remove_packages mysql-\*
	autoremove_packages
        autoclean_packages
        clean_packages
        rm -rf /etc/mysql/ /var/lib/mysql/ /var/log/mysql
        clean_packages

	log "reinstalling ${DB_SERVER}..."
        if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
          debconf-set-selections <<< "${DB_SERVER} mysql-server/root_password password ${CARME_PASSWORD_MYSQL}"
          debconf-set-selections <<< "${DB_SERVER} mysql-server/root_password_again password ${CARME_PASSWORD_MYSQL}"
	fi

        install_packages ${DB_SERVER}

        if [[ $SYSTEM_DIST == "rocky" ]]; then
          systemctl enable --now ${DB_SERVICE}
          mysqladmin -u root password ${CARME_PASSWORD_MYSQL}
        fi
      elif [[ $REPLY =~ ^[Nn]$ || $REPLY == "No" || $REPLY == "no"  ]]; then
        die "[install_mysql.sh]: You have cancelled the request. Please try again."
      else
        die "[install_mysql.sh]: Your answer was not yes or no. Please try again."
      fi
    fi 
  else
    log "installing ${DB_SERVER}..."
    
    if [[ $SYSTEM_DIST == "ubuntu" || $SYSTEM_DIST == "debian" ]]; then
      debconf-set-selections <<< "${DB_SERVER} mysql-server/root_password password $CARME_PASSWORD_MYSQL"
      debconf-set-selections <<< "${DB_SERVER} mysql-server/root_password_again password $CARME_PASSWORD_MYSQL"
    fi

    install_packages ${DB_SERVER}
    autoremove_packages
    clean_packages

    if [[ $SYSTEM_DIST == "rocky" ]]; then
      systemctl enable --now ${DB_SERVICE}
      mysqladmin -u root password ${CARME_PASSWORD_MYSQL}
    fi
  fi

elif  [[ ${CARME_DB} == "no" ]]; then
  if ! [[ $(installed "${DB_SERVER}" "single") == "installed" ]]; then
    die "[install_mysql.sh]: ${DB_SERVER} is not installed. To install it, consider CARME_DB=yes in CarmeConfig.start and try again."
  fi
fi

# configure database server ----------------------------------------------------------------
log "configuring ${DB_SERVER}..."

export MYSQL_PWD=${CARME_PASSWORD_MYSQL}
if  [[ ${CARME_DB} == "no" ]]; then

  # check mysql root password
  if ! mysql -uroot -e 'quit' &> /dev/null; then
    die "[install_mysql.sh]: CARME_PASSWORD_MYSQL in CarmeConfig.start was not set properly. It must be your database root password. Modify it and try again."
  fi

  # check mysql port
  MYSQL_PORT=$(mysql -uroot -e 'show global variables like "port"' | grep "port")
  if ! [[ ${MYSQL_PORT} =~ "${CARME_DB_DEFAULT_PORT}" ]]; then
    die "[install_mysql.sh]: CARME_DB_DEFAULT_PORT in CarmeConfig.start was not set properly. Your database port is ${MYSQL_PORT}. Modify and try again."
  fi
  
  # check password policy
  MYSQL_POLICY=$(mysql -uroot -e "SHOW VARIABLES LIKE 'validate_password.policy';")

  if [[ ${MYSQL_POLICY} =~ "MEDIUM" ]]; then
    PASSWORD_POLICY="MEDIUM"
  elif [[ ${MYSQL_POLICY} =~ "STRONG" ]]; then
    PASSWORD_POLICY="STRONG"
  else
    PASSWORD_POLICY="LOW"
  fi

  mysql -uroot -e "SET GLOBAL validate_password.policy=LOW;
                   CREATE DATABASE IF NOT EXISTS ${CARME_DB_SLURM_NAME};
                   CREATE DATABASE IF NOT EXISTS ${CARME_DB_DEFAULT_NAME};
                   CREATE USER IF NOT EXISTS '${CARME_DB_SLURM_USER}'@'localhost' IDENTIFIED BY '$CARME_PASSWORD_SLURM';
                   CREATE USER IF NOT EXISTS '${CARME_DB_DEFAULT_USER}'@'localhost' IDENTIFIED BY '$CARME_PASSWORD_DJANGO';
                   GRANT ALL PRIVILEGES ON ${CARME_DB_SLURM_NAME}.* TO '${CARME_DB_SLURM_USER}'@'localhost';
                   GRANT ALL PRIVILEGES ON ${CARME_DB_SLURM_NAME}.* to '${CARME_DB_DEFAULT_USER}'@'localhost';
                   GRANT ALL PRIVILEGES ON ${CARME_DB_DEFAULT_NAME}.* to '${CARME_DB_DEFAULT_USER}'@'localhost';
		   SET GLOBAL validate_password.policy=${PASSWORD_POLICY};
                   FLUSH PRIVILEGES;";

elif [[ ${CARME_DB} == "yes" ]]; then
  mysql -uroot -e "CREATE DATABASE IF NOT EXISTS ${CARME_DB_SLURM_NAME};
                   CREATE DATABASE IF NOT EXISTS ${CARME_DB_DEFAULT_NAME};
                   CREATE USER IF NOT EXISTS '${CARME_DB_SLURM_USER}'@'localhost' IDENTIFIED BY '$CARME_PASSWORD_SLURM';
                   CREATE USER IF NOT EXISTS '${CARME_DB_DEFAULT_USER}'@'localhost' IDENTIFIED BY '$CARME_PASSWORD_DJANGO';
                   GRANT ALL PRIVILEGES ON ${CARME_DB_SLURM_NAME}.* TO '${CARME_DB_SLURM_USER}'@'localhost';
                   GRANT ALL PRIVILEGES ON ${CARME_DB_SLURM_NAME}.* to '${CARME_DB_DEFAULT_USER}'@'localhost';
                   GRANT ALL PRIVILEGES ON ${CARME_DB_DEFAULT_NAME}.* to '${CARME_DB_DEFAULT_USER}'@'localhost';
                   ALTER USER 'root'@'localhost' IDENTIFIED BY '${CARME_PASSWORD_MYSQL}';
                   FLUSH PRIVILEGES;";  
fi

# configure my.cnf: memory restriction -----------------------------------------------------
log "configuring my.cnf..."

MY_CNF_PATH="/etc/mysql/my.cnf"
CARME_CNF_DIR="/etc/mysql/carme.cnf.d"
if [[ $SYSTEM_DIST == "rocky" ]]; then
  MY_CNF_PATH="/etc/my.cnf"
  CARME_CNF_DIR="/etc/carme.cnf.d"
fi
systemctl stop ${DB_SERVICE}.service

if ! grep -q "^!includedir ${CARME_CNF_DIR}$" "$MY_CNF_PATH"; then
  printf "\n!includedir ${CARME_CNF_DIR}\n" >> $MY_CNF_PATH
fi

mkdir -p "${CARME_CNF_DIR}"

if [[ "${CARME_DB_DEFAULT_PORT}" == "3306" ]]; then
  cat << EOF > "${CARME_CNF_DIR}/innodb.cnf"
[mysqld]
innodb_buffer_pool_size=4096M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
max_allowed_packet=16M
EOF
else
  cat << EOF > "${CARME_CNF_DIR}/innodb.cnf"
[mysqld]
innodb_buffer_pool_size=4096M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
max_allowed_packet=16M
port=${CARME_DB_DEFAULT_PORT}
EOF
fi

if [[ $SYSTEM_DIST == "rocky" ]]; then
  cat << EOF > "${CARME_CNF_DIR}/socket.cnf"
[mysqld]
socket=/run/mysqld/mysqld.sock

[client]
socket=/run/mysqld/mysqld.sock
EOF
  ln -s /run/mysqld/mysqld.sock /var/lib/mysql/mysql.sock
fi

# configure debian.cnf: password restriction in mariadb -----------------------------------
if [[ -f "/etc/mysql/debian.cnf" ]]; then
  mv "/etc/mysql/debian.cnf" "/etc/mysql/debian.cnf.bak"
  touch /etc/mysql/debian.cnf
  cat << EOF >> /etc/mysql/debian.cnf
# THIS FILE IS OBSOLETE. STOP USING IT IF POSSIBLE.
# This file exists only for backwards compatibility for
# tools that run '--defaults-file=/etc/mysql/debian.cnf'
# and have root level access to the local filesystem.
# With those permissions one can run 'mariadb' directly
# anyway thanks to unix socket authentication and hence
# this file is useless. See package README for more info.
[client]
host     = localhost
user     = root
password = ${CARME_PASSWORD_MYSQL}
[mysql_upgrade]
host     = localhost
user     = root
password = ${CARME_PASSWORD_MYSQL}
# THIS FILE WILL BE REMOVED IN A FUTURE DEBIAN RELEASE.
EOF

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
# TODO: enable this on rocky

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
