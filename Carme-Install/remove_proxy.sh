#!/bin/bash
#-----------------------------------------------------------------------------------------#
#------------------------------------ remove PROXY ---------------------------------------#
#-----------------------------------------------------------------------------------------#

# bash buildins ---------------------------------------------------------------------------
set -e
set -o pipefail

# basic functions -------------------------------------------------------------------------
PATH_CARME=/opt/Carme
source ${PATH_CARME}/Carme-Install/basic_functions.sh

# uninstall variables ---------------------------------------------------------------------
PATH_PROXY_CONTAINERIMAGE=${PATH_CARME}/Carme-ContainerImages/Carme-Proxy-Container
PATH_PROXY_ROUTES=/opt/Carme-Proxy-Routes
PATH_PROXY_CONF=${PATH_CARME}/Carme-Proxy/traefik-conf
PATH_PROXY_LOG=/var/log/carme/proxy
PATH_SYSTEMD=/etc/systemd/system

FILE_PROXY_STATIC=${PATH_PROXY_CONF}/static.toml
FILE_PROXY_TRAEFIK=${PATH_PROXY_CONF}/traefik.toml
FILE_PROXY_RECIPE=${PATH_PROXY_CONTAINERIMAGE}/proxy.recipe
FILE_PROXY_SYSTEMD=${PATH_SYSTEMD}/carme-proxy.service
FILE_FRONTEND_SYSTEMD=${PATH_SYSTEMD}/carme-frontend.service
FILE_PROXY_SYSTEMD_MULTI=${PATH_SYSTEMD}/multi-user.target.wants/carme-proxy.service

# remove static.toml symlink --------------------------------------------------------------
log "removing symlink..."

rm -f "${PATH_PROXY_ROUTES}/routes/static.toml"

# remove proxy from frontend service ------------------------------------------------------
log "removing proxy bind mount in frontend service..."

if [[ -f ${FILE_FRONTEND_SYSTEMD} ]]; then
  PROXY_BIND=$(echo $(cat "${FILE_FRONTEND_SYSTEMD}" | grep -c "${PATH_PROXY_ROUTES}/routes:/opt/traefik/routes"))
  [[ $PROXY_BIND == 2 ]] && sed -i 's/ -B "\/opt\/Carme-Proxy-Routes\/routes:\/opt\/traefik\/routes"//' ${FILE_FRONTEND_SYSTEMD}

  systemctl daemon-reload
  systemctl restart carme-frontend
  systemctl is-active --quiet carme-frontend && IS_ACTIVE=true || IS_ACTIVE=false

  [[ ${IS_ACTIVE} = false ]] && die "[remove_proxy.sh]: carme-frontend.service is not running. proxy bind mount was not properly removed. Please contact us."
fi

# remove proxy service --------------------------------------------------------------------
log "removing proxy recipe..."

if [[ -f ${FILE_PROXY_SYSTEMD} ]]; then
  systemctl stop carme-proxy.service
  rm -f ${FILE_PROXY_SYSTEMD}
fi

[[ -f ${FILE_PROXY_SYSTEMD_MULTI} ]] && rm -f ${FILE_PROXY_SYSTEMD_MULTI}

systemctl daemon-reload

# remove proxy image ----------------------------------------------------------------------
log "removing proxy image..."

rm -f "${PATH_PROXY_CONTAINERIMAGE}/proxy.sif"
rm -f "${PATH_PROXY_CONTAINERIMAGE}/proxy.sif.bak"

# remove proxy .toml files ----------------------------------------------------------------
log "removing proxy .toml files..."

rm -f ${FILE_PROXY_STATIC}
rm -f ${FILE_PROXY_TRAEFIK}

# remove proxy singularity recipe ---------------------------------------------------------
log "removing proxy recipe..."

rm -f ${FILE_PROXY_RECIPE}

# remove proxy directories ----------------------------------------------------------------
log "removing proxy directories..."

rm -rf ${PATH_PROXY_ROUTES}
rm -rf ${PATH_PROXY_LOG}

log "carme-proxy successfully removed."
