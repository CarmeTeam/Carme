#!/bin/bash
#-----------------------------------------------------------------------------------------#
#------------------------------------ remove FRONTEND ------------------------------------#
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

  CARME_PASSWORD_DJANGO=$(get_variable CARME_PASSWORD_DJANGO ${FILE_START_CONFIG})
  [[ -z ${CARME_PASSWORD_DJANGO} ]] && die "[remove_frontend.sh]: CARME_PASSWORD_DJANGO not set."

else
  die "[remove_frontend.sh]: ${FILE_START_CONFIG} not found."
fi


# uninstall variables -----------------------------------------------------------------------
PATH_FRONTEND_CONTAINERIMAGE=${PATH_CARME}/Carme-ContainerImages/Carme-Frontend-Container
PATH_SERVER_CONF=${PATH_CARME}/Carme-Frontend/Carme-Server-Conf
PATH_SYSTEMD=/etc/systemd/system
PATH_CONFIG=/etc/carme

FILE_FRONTEND_SYSTEMD_MULTI=${PATH_SYSTEMD}/multi-user.target.wants/carme-frontend.service
FILE_FRONTEND_SYSTEMD=${PATH_SYSTEMD}/carme-frontend.service
FILE_FRONTEND_CONFIG=${PATH_CONFIG}/CarmeConfig.frontend

# set database password ---------------------------------------------------------------------
export MYSQL_PWD=${CARME_PASSWORD_DJANGO}

# clean tables ------------------------------------------------------------------------------
log "cleaning tables..."

if systemctl cat mysql &>/dev/null
then
  systemctl is-active --quiet mysql || die "[install_frontend.sh]: mysql.service is not running."

  # primary tables
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS auth_user(foo VARCHAR(10))"
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_project(foo VARCHAR(10))"
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_resourcetemplate(foo VARCHAR(10))"
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_accelerator(foo VARCHAR(10))"
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_image(foo VARCHAR(10))"
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_flag(foo VARCHAR(10))"

  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table auth_user"
  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_project"
  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_resourcetemplate"
  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_accelerator"
  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_image"
  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_flag"

  # secondary tables
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_projectmember(foo VARCHAR(10))"
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_projecthastemplate(foo VARCHAR(10))"
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_templatehasaccelerator(foo VARCHAR(10))"
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_templatehasimage(foo VARCHAR(10))"
  mysql --user=django webfrontend -e "CREATE TABLE IF NOT EXISTS projects_imagehasflag(foo VARCHAR(10))"

  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_projectmember"
  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_projecthastemplate"
  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_templatehasaccelerator"
  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_templatehasimage"
  mysql --user=django webfrontend -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_imagehasflag"

fi

# remove frontend service ------------------------------------------------------------------
log "removing frontend service..."

if [[ -f ${FILE_FRONTEND_SYSTEMD} ]]; then
    systemctl stop carme-frontend.service
    rm -f ${FILE_FRONTEND_SYSTEMD}
fi

[[ -h ${FILE_FRONTEND_SYSTEMD_MULTI} ]] && rm -f ${FILE_FRONTEND_SYSTEMD_MULTI}

systemctl daemon-reload

# remove frontend image ----------------------------------------------------------------------
log "removing frontend image..."

rm -f "${PATH_FRONTEND_CONTAINERIMAGE}/frontend.sif"
rm -f "${PATH_FRONTEND_CONTAINERIMAGE}/frontend.sif.bak"

# remove frontend directories ----------------------------------------------------------------
log "removing frontend directories..."

rm -rf /var/run/carme/frontend
rm -rf /var/log/carme/apache

# remove frontend server conf ----------------------------------------------------------------
log "removing server config..."

rm -rf ${PATH_SERVER_CONF}

# remove frontend config ---------------------------------------------------------------------------
log "removing frontend config..."

rm -f "${FILE_FRONTEND_CONFIG}"
rm -f "${FILE_FRONTEND_CONFIG}.bak"

log "carme-frontend successfully removed."
