#-----------------------------------------------------------------------------------------#
#----------------------------------- remove Database -------------------------------------#
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
  CARME_SLURM=$(get_variable CARME_SLURM ${FILE_START_CONFIG})
  CARME_DB_SERVER=$(get_variable CARME_DB_SERVER ${FILE_START_CONFIG})
  CARME_PASSWORD_MYSQL=$(get_variable CARME_PASSWORD_MYSQL ${FILE_START_CONFIG})

  [[ -z ${CARME_DB} ]] && die "[remove_database.sh]: CARME_DB not set."
  [[ -z ${CARME_SLURM} ]] && die "[remove_database.sh]: CARME_SLURM not set."
  [[ -z ${CARME_DB_SERVER} ]] && die "[remove_database.sh]: CARME_DB_SERVER not set."
  [[ -z ${CARME_PASSWORD_MYSQL} ]] && die "[remove_database.sh]: CARME_PASSWORD_MYSQL not set."

else
  die "[remove_database.sh]: ${FILE_START_CONFIG} not found."
fi

# check variables --------------------------------------------------------------------------
log "checking variables..."

if ! [[ ${CARME_DB_SERVER} == "mariadb" || ${CARME_DB_SERVER} == "mysql" ]]; then
  die "[remove_database.sh]: CARME_DB_SERVER in CarmeConfig.start was not set properly. It must be mariadb or mysql." 
fi
if ! [[ ${CARME_SLURM} == "yes" || ${CARME_SLURM} == "no" ]]; then
  die "[remove_database.sh]: CARME_SLURM in CarmeConfig.start was not set properly. It must be yes or no."
fi
if ! [[ ${CARME_DB} == "yes" || ${CARME_DB} == "no" ]]; then
  die "[remove_database.sh]: CARME_DB in CarmeConfig.start was not set properly. It must be yes or no."
fi

# set database server ----------------------------------------------------------------------
log "setting database server..."

if [[ ${CARME_DB_SERVER} == "mariadb" ]]; then
  DB_SERVER="mariadb-server"
  DB_SERVICE="mariadb"
elif [[ ${CARME_DB_SERVER} == "mysql" ]]; then
  DB_SERVER="mysql-server-8.0"
  DB_SERVICE="mysql"
fi

# remove database --------------------------------------------------------------------------
if [[ ${CARME_SLURM} == "yes" ]]; then
  log "removing webfrontend and slurm_acct_db databases..."
elif [[ ${CARME_SLURM} == "no" ]]; then
  log "removing webfrontend database..."
fi

export MYSQL_PWD=${CARME_PASSWORD_MYSQL}
mysql --user=root -e "DROP DATABASE webfrontend;" 2>/dev/null || true
mysql --user=root -e "DROP USER 'django'@'localhost';" 2>/dev/null || true

if [[ ${CARME_SLURM} == "yes" ]]; then
  mysql --user=root -e "DROP DATABASE slurm_acct_db;" 2>/dev/null || true
  mysql --user=root -e "DROP USER 'slurm'@'localhost';" 2>/dev/null || true
fi

# remove package --------------------------------------------------------------------------
log "removing package..."

if [[ ${CARME_DB} == "yes" ]]; then
  apt-get remove --purge ${DB_SERVICE}-server* -y
  apt-get remove --purge mysql-\* -y
  apt -y autoremove
  apt autoclean
  apt clean all
  rm -rf /etc/mysql/ /var/lib/mysql/ /var/log/mysql
  apt clean

  log "${DB_SERVICE} successfully removed."
elif [[ ${CARME_DB} == "no" ]]; then
  log "carme in ${DB_SERVICE} successfully removed."
fi
