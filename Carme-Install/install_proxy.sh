#!/bin/bash
#-----------------------------------------------------------------------------------------#
#--------------------------------- PROXY installation ------------------------------------#
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
  
  SYSTEM_OS=$(get_variable SYSTEM_OS ${FILE_START_CONFIG})
  SYSTEM_ARCH=$(get_variable SYSTEM_ARCH ${FILE_START_CONFIG})
  SYSTEM_HDWR=$(get_variable SYSTEM_HDWR ${FILE_START_CONFIG})
  PROXY_VERSION=$(get_variable PROXY_VERSION ${FILE_START_CONFIG})
  CARME_FRONTEND_IP=$(get_variable CARME_FRONTEND_IP ${FILE_START_CONFIG})	

  [[ -z ${SYSTEM_OS} ]] && die "[install_proxy.sh]: SYSTEM_OS not set."
  [[ -z ${SYSTEM_ARCH} ]] && die "[install_proxy.sh]: SYSTEM_ARCH not set."
  [[ -z ${SYSTEM_HDWR} ]] && die "[install_proxy.sh]: SYSTEM_HDWR not set."
  [[ -z ${PROXY_VERSION} ]] && die "[install_proxy.sh]: PROXY_VERSION not set."
  [[ -z ${CARME_FRONTEND_IP} ]] && die "[install_proxy.sh]: CARME_FRONTEND_IP not set."

else
  die "[install_proxy.sh] ${FILE_START_CONFIG} not found."
fi

# install variables -----------------------------------------------------------------------
PATH_PROXY_CONTAINERIMAGE=${PATH_CARME}/Carme-ContainerImages/Carme-Proxy-Container
PATH_SINGULARITY=${PATH_CARME}/Carme-Vendors/singularity/bin
PATH_PROXY_CONFIG=${PATH_CARME}/Carme-Proxy/traefik-conf
PATH_PROXY_ROUTES=/opt/Carme-Proxy-Routes
PATH_PROXY_SSL=${PATH_CARME}/Carme-Proxy/SSL
PATH_PROXY_LOG=/var/log/carme/proxy
PATH_SYSTEMD=/etc/systemd/system

FILE_PROXY_CONTAINERIMAGE=${PATH_PROXY_CONTAINERIMAGE}/proxy.sif
FILE_PROXY_STATIC=${PATH_PROXY_CONFIG}/static.toml
FILE_PROXY_TRAEFIK=${PATH_PROXY_CONFIG}/traefik.toml
FILE_PROXY_RECIPE=${PATH_PROXY_CONTAINERIMAGE}/proxy.recipe
FILE_PROXY_SYSTEMD=${PATH_SYSTEMD}/carme-proxy.service
FILE_FRONTEND_SYSTEMD=${PATH_SYSTEMD}/carme-frontend.service
FILE_SINGULARITY=${PATH_SINGULARITY}/singularity

# create static.toml and traefik.toml -----------------------------------------------------
log "creating static.toml and traefik.toml files"

mkdir -p ${PATH_PROXY_CONFIG}

[[ -f ${FILE_PROXY_STATIC} ]] && rm ${FILE_PROXY_STATIC}
touch ${FILE_PROXY_STATIC}
cat << EOF >> ${FILE_PROXY_STATIC}
# static.toml
[http.routers]
  [http.routers.dashboard]
    service = "api@internal"

  [http.routers.carme]
    entryPoints = ["https"]
    rule = "Host(\`localhost\`)"
    service = "carme"

[http.services]

  [[http.services.carme.loadBalancer.servers]]
    url = "http://${CARME_FRONTEND_IP}:8888"

[http.middlewares]
  [http.middlewares.stripprefix-theia.stripPrefixRegex]
    regex = ["/ta_[a-z0-9]+/"]

  [http.middlewares.proxy-auth-Carme.forwardAuth]
    address = "http://${CARME_FRONTEND_IP}:8888/proxy_auth/"
EOF

[[ -f ${FILE_PROXY_TRAEFIK} ]] && rm ${FILE_PROXY_TRAEFIK}
touch ${FILE_PROXY_TRAEFIK}
cat << EOF >> ${FILE_PROXY_TRAEFIK}
# traefik.toml
[log]
  level = "INFO"
  filePath = "/var/log/traefik/traefik.log"

[providers]
  providersThrottleDuration = "2s"
  [providers.file]
    directory = "/opt/traefik/routes"
    watch = true

[api]
  insecure = true
  dashboard = true

[entryPoints]
  [entryPoints.http]
    address = ":10080"
  [entryPoints.dashboard]
    address = ":8081"
  [entryPoints.https]
    address = ":10443"

[serversTransport]
  insecureSkipVerify = true
EOF

# create proxy service --------------------------------------------------------------------
log "creating proxy service..."

if [[ -f ${FILE_PROXY_SYSTEMD} ]]; then
    systemctl stop carme-proxy.service
    rm ${FILE_PROXY_SYSTEMD}
fi
touch ${FILE_PROXY_SYSTEMD}

cat << EOF >> ${FILE_PROXY_SYSTEMD}
[Unit]
Description=Carme Proxy
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${FILE_SINGULARITY} run -B "${PATH_PROXY_CONFIG}/traefik.toml:/opt/traefik/traefik.toml" -B "${PATH_PROXY_CONFIG}/static.toml:/opt/traefik/static.toml" -B "${PATH_PROXY_ROUTES}/routes:/opt/traefik/routes" -B "${PATH_PROXY_LOG}:/var/log/traefik" -B "${PATH_PROXY_SSL}:/opt/traefik/SSL" "${FILE_PROXY_CONTAINERIMAGE}"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# make proxy directories ---------------------------------------------------------------
log "creating proxy directories..."

mkdir -p ${PATH_PROXY_CONTAINERIMAGE}
mkdir -p ${PATH_PROXY_ROUTES}/routes
mkdir -p ${PATH_PROXY_LOG}

chown -R www-data:www-data ${PATH_PROXY_ROUTES}
chown -R www-data:www-data ${PATH_PROXY_LOG}

# make proxy singularity recipe --------------------------------------------------------

[[ -f ${FILE_PROXY_RECIPE} ]] && rm ${FILE_PROXY_RECIPE}
touch ${FILE_PROXY_RECIPE}

cat << EOF >> ${FILE_PROXY_RECIPE}
BootStrap: debootstrap
OSVersion: stable
MirrorURL: http://ftp.de.debian.org/debian/
%help
  If you need any help you should ask the maintainer of this image.

%labels
  MAINTAINER CC-HPC Fraunhofer ITWM

%setup
  mkdir -p '${SINGULARITY_ROOTFS}/opt/traefik'

%files
  ${PATH_PROXY_SSL} /opt/traefik/SSL
  ${PATH_PROXY_CONFIG}/traefik.toml /opt/traefik/traefik.toml
  ${PATH_PROXY_CONFIG}/static.toml /opt/traefik/routes/static.toml

%post
  apt update
  apt upgrade -y

  # base stuff ---------------------------------------------------------------------------------------------------------------------
  apt install -y vim nano less htop wget

  wget -qO- https://github.com/traefik/traefik/releases/download/v${PROXY_VERSION}/traefik_v${PROXY_VERSION}_${SYSTEM_OS}_${SYSTEM_ARCH}.tar.gz | tar -xzf -  -C /opt/traefik traefik
  chmod +x /opt/traefik/traefik

  chown -R www-data:www-data /opt/traefik

  # clean-up -----------------------------------------------------------------------------------------------------------------------
  apt autoremove -y
  apt clean

%runscript
  exec runuser -u www-data -- /opt/traefik/traefik --configfile=/opt/traefik/traefik.toml

%startscript
  runuser -u www-data -- /opt/traefik/traefik --configfile=/opt/traefik/traefik.toml
EOF

# build proxy image --------------------------------------------------------------------
log "building proxy image..."

if [[ $(installed "debootstrap" "single") == "not installed" ]]; then
  apt install debootstrap -y
fi

log "initializing build (please wait)..."
${FILE_SINGULARITY} build "/tmp/proxy.sif" "${PATH_PROXY_CONTAINERIMAGE}/proxy.recipe"
[[ -f "${PATH_PROXY_CONTAINERIMAGE}/proxy.sif" ]] && mv "${PATH_PROXY_CONTAINERIMAGE}/proxy.sif" "${PATH_PROXY_CONTAINERIMAGE}/proxy.sif.bak"
mv "/tmp/proxy.sif" "${PATH_PROXY_CONTAINERIMAGE}/proxy.sif"

# start proxy service ------------------------------------------------------------------
log "starting proxy service..."

systemctl is-active --quiet carme-proxy && is_active=true || is_active=false
systemctl is-enabled --quiet carme-proxy && is_enabled=true || is_enabled=false

if [[ ${is_active} = false ]]; then
  systemctl start carme-proxy.service
  systemctl is-active --quiet carme-proxy || die "[install_proxy.sh]: carme-proxy.service is not running."
  if [[ ${is_enabled} = false ]]; then
    systemctl enable carme-proxy.service
    systemctl is-enabled --quiet carme-proxy || die "[install_proxy.sh]: carme-proxy.service is not enabled."
  fi
else
  systemctl restart carme-proxy.service
  systemctl is-active --quiet carme-proxy || die "[install_proxy.sh]: carme-proxy.service is not running."
  if [[ ${is_enabled} = false ]]; then
    systemctl enable carme-proxy.service
    systemctl is-enabled --quiet carme-proxy || die "[install_proxy.sh]: carme-proxy.service is not enabled."
  fi
fi

# add proxy to frontend service --------------------------------------------------------
log "setting proxy bind mount in frontend service..."

PROXY_BIND=$(echo $(cat "${FILE_FRONTEND_SYSTEMD}" | grep -c "${PATH_PROXY_ROUTES}/routes:/opt/traefik/routes"))

if [[ $PROXY_BIND == 0 ]]; then
  sed -i 's/exec/& -B "\/opt\/Carme-Proxy-Routes\/routes:\/opt\/traefik\/routes"/g' ${FILE_FRONTEND_SYSTEMD}
  PROXY_BIND=$(echo $(cat ${FILE_FRONTEND_SYSTEMD} | grep -c "${PATH_PROXY_ROUTES}/routes:/opt/traefik/routes"))
  if [[ $PROXY_BIND != 2 ]]; then
    die "[install_proxy.sh]: proxy bind mount is not set properly. Please contact us."
  fi
else
  if [[ $PROXY_BIND != 2 ]]; then
    die "[install_proxy.sh]: proxy bind mount is not set properly. Remove \"${PATH_PROXY_ROUTES}/routes:/opt/traefik/routes\" in ${FILE_FRONTEND_SYSTEMD} and restart install_proxy."
  fi
fi

systemctl daemon-reload
systemctl restart carme-frontend
systemctl is-active --quiet carme-frontend && is_active=true || is_active=false

if [[ ${is_active} = false ]]; then
  die "[install_proxy.sh]: carme-frontend.service is not running. Please contact us."
fi

# add symlink to proxy static.toml -----------------------------------------------------
log "setting symlink..."

cd ${PATH_PROXY_ROUTES}/routes
[[ -h "static.toml" ]] && rm "static.toml"
ln -s ../static.toml static.toml

log "carme-proxy successfully installed."
