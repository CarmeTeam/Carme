#!/bin/bash
#-----------------------------------------------------------------------------------------#
#----------------------------------- LDAP installation -----------------------------------#
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

  CARME_LDAP=$(get_variable CARME_LDAP ${FILE_START_CONFIG})
  CARME_USER=$(get_variable CARME_USER ${FILE_START_CONFIG})
  CARME_GROUP=$(get_variable CARME_GROUP ${FILE_START_CONFIG})
  CARME_SYSTEM=$(get_variable CARME_SYSTEM ${FILE_START_CONFIG})
  CARME_NODE_LIST=$(get_variable CARME_NODE_LIST ${FILE_START_CONFIG})
  CARME_PASSWORD_USER=$(get_variable CARME_PASSWORD_USER ${FILE_START_CONFIG})
  CARME_LDAP_SERVER_PW=$(get_variable CARME_LDAP_SERVER_PW ${FILE_START_CONFIG})

  [[ -z ${CARME_LDAP} ]] && die "[install_ldap.sh]: CARME_LDAP not set."
  [[ -z ${CARME_USER} ]] && die "[install_ldap.sh]: CARME_USER not set."
  [[ -z ${CARME_GROUP} ]] && die "[install_ldap.sh]: CARME_GROUP not set."
  [[ -z ${CARME_SYSTEM} ]] && die "[install_ldap.sh]: CARME_SYSTEM not set."
  [[ -z ${CARME_NODE_LIST} ]] && die "[install_ldap.sh]: CARME_NODE_LIST not set."
  [[ -z ${CARME_PASSWORD_USER} ]] && die "[install_ldap.sh]: CARME_PASSWORD_USER not set."
  [[ -z ${CARME_LDAP_SERVER_PW} ]] && die "[install_ldap.sh]: CARME_LDAP_SERVER_PW not set."

else
  die "[install_ldap.sh]: ${FILE_START_CONFIG} not found."
fi

# check system ----------------------------------------------------------------------------
if ! [[ ${CARME_SYSTEM} == "single" || ${CARME_SYSTEM} == "multi" ]]; then
  die "[install_ldap.sh]: CARME_SYSTEM in CarmeConfig.start was not set properly. It must be \`single\` or \`multi\`."
fi
if ! [[ ${CARME_LDAP} == "yes" || ${CARME_LDAP} == "no" ]]; then
  die "[install_ldap.sh]: CARME_LDAP in CarmeConfig.start was not set properly. It must be \`yes\` or \`no\`."
fi

# installation / configuration starts -----------------------------------------------------
if [[ ${CARME_LDAP} == "yes" ]]; then
  log "starting ldap installation..."
else
  log "starting ldap configuration..."
fi

# install packages ------------------------------------------------------------------------
if [[ ${CARME_LDAP} == "yes" ]]; then
  log "installing packages..."

  if [[ ${CARME_SYSTEM} == "single" ]]; then
    MY_PKGS=(slapd ldapscripts libnss-ldapd)
    MISSING_PKGS=""

    for MY_PKG in ${MY_PKGS[@]}; do
      if [[ $(installed $MY_PKG "single") == "not installed" ]]; then
        MISSING_PKGS+=" $MY_PKG"
      fi
    done

    if [ ! -z "$MISSING_PKGS" ]; then
      dpkg --configure -a
      DEBIAN_FRONTEND=noninteractive apt install $MISSING_PKGS -y
    fi

    for MY_PKG in ${MY_PKGS[@]}; do
      if [[ $(installed $MY_PKG "single") == "not installed" ]]; then
        die "[install_ldap.sh]: $MY_PKG was not installed. Please try again."
      fi
    done
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then

    # head-node -----------------------------------
    HEAD_NODE_PKGS=(slapd ldapscripts libnss-ldapd)
    MISSING_HEAD_NODE_PKGS=""

    for HEAD_NODE_PKG in ${HEAD_NODE_PKGS[@]}; do
      if [[ $(installed $HEAD_NODE_PKG "single") == "not installed" ]]; then
        MISSING_HEAD_NODE_PKGS+=" $HEAD_NODE_PKG"
      fi
    done

    if [ ! -z "$MISSING_HEAD_NODE_PKGS" ]; then
      dpkg --configure -a
      DEBIAN_FRONTEND=noninteractive apt install $MISSING_HEAD_NODE_PKGS -y
    fi

    for HEAD_NODE_PKG in ${HEAD_NODE_PKGS[@]}; do
      if [[ $(installed $HEAD_NODE_PKG "single") == "not installed" ]]; then
        die "[install_ldap.sh]: $HEAD_NODE_PKG was not installed. Please try again."
      fi
    done

    # compute-nodes -----------------------------
    COMPUTE_NODE_PKGS=(libnss-ldapd)
    MISSING_COMPUTE_NODE_PKGS=""

    for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      for COMPUTE_NODE_PKG in ${COMPUTE_NODE_PKGS[@]}; do
        if [[ $(installed $COMPUTE_NODE_PKG $COMPUTE_NODE) == "not installed" ]]; then
          MISSING_COMPUTE_NODE_PKGS+=" $COMPUTE_NODE_PKG"
        fi
      done
      if [ ! -z "$MISSING_COMPUTE_NODE_PKGS" ]; then
	ssh -t $COMPUTE_NODE "dpkg --configure -a"
        ssh -t $COMPUTE_NODE "DEBIAN_FRONTEND=noninteractive apt install $MISSING_COMPUTE_NODE_PKGS -y"
      fi
      for COMPUTE_NODE_PKG in ${COMPUTE_NODE_PKGS[@]}; do
        if [[ $(installed $COMPUTE_NODE_PKG $COMPUTE_NODE) == "not installed" ]]; then
          die "[install_ldap.sh]: $COMPUTE_NODE_PKG in node $COMPUTE_NODE was not installed. Please try again."
        fi
      done
    done
  fi
fi

# configure packages ----------------------------------------------------------------------
if [[ ${CARME_LDAP} == "yes" ]]; then
  log "configuring packages..."

  if [[ ${CARME_SYSTEM} == "single" ]]; then
    echo 'BASE   dc=nodomain' >> /etc/ldap/ldap.conf
    echo 'URI    ldap://127.0.0.1' >> /etc/ldap/ldap.conf

    sed -i 's/^BINDDN=.*/BINDDN="cn=admin,dc=nodomain"/' /etc/ldapscripts/ldapscripts.conf
    echo -n ${CARME_LDAP_SERVER_PW} > /etc/ldapscripts/ldapscripts.passwd

    sed -i "s|^uri .*|uri ldap://127.0.0.1|" /etc/nslcd.conf
    sed -i 's/base .*/base dc=nodomain/' /etc/nslcd.conf
    sed -i '/^passwd:.*ldap/b; /^passwd:/ s/\s*$/ ldap/' /etc/nsswitch.conf
    sed -i '/^group:.*ldap/b; /^group:/ s/\s*$/ ldap/' /etc/nsswitch.conf
    sed -i '/^shadow:.*ldap/b; /^shadow:/ s/\s*$/ ldap/' /etc/nsswitch.conf

    systemctl enable --now slapd
    systemctl enable --now nslcd
    systemctl enable --now nscd

    LDAP_PASSWORD_HASH=$(slappasswd -s "${CARME_LDAP_SERVER_PW}")

    printf "dn: olcDatabase={1}mdb,cn=config\nchangetype: modify\nreplace: olcRootPW\nolcRootPW: ${LDAP_PASSWORD_HASH}\n" | ldapmodify -Q -Y EXTERNAL -H ldapi:///

    USER_PASSWORD_HASH=$(slappasswd -s "${CARME_PASSWORD_USER}")

    if [[ ! $(ldapfinger ${CARME_USER}) ]]; then
      ldapinit -s
      ldapaddgroup ${CARME_GROUP}
      ldapadduser ${CARME_USER} ${CARME_GROUP}
      ldapsetpasswd ${CARME_USER} ${USER_PASSWORD_HASH}
      systemctl restart nslcd
    fi

    systemctl restart nslcd
  elif [[ ${CARME_SYSTEM} == "multi" ]]; then

    # head-node -----------------------------------
    echo 'BASE   dc=nodomain' >> /etc/ldap/ldap.conf
    echo 'URI    ldap://127.0.0.1' >> /etc/ldap/ldap.conf

    sed -i 's/^BINDDN=.*/BINDDN="cn=admin,dc=nodomain"/' /etc/ldapscripts/ldapscripts.conf
    echo -n ${CARME_LDAP_SERVER_PW} > /etc/ldapscripts/ldapscripts.passwd

    sed -i "s|^uri .*|uri ldap://127.0.0.1|" /etc/nslcd.conf
    sed -i 's/base .*/base dc=nodomain/' /etc/nslcd.conf
    sed -i '/^passwd:.*ldap/b; /^passwd:/ s/\s*$/ ldap/' /etc/nsswitch.conf
    sed -i '/^group:.*ldap/b; /^group:/ s/\s*$/ ldap/' /etc/nsswitch.conf
    sed -i '/^shadow:.*ldap/b; /^shadow:/ s/\s*$/ ldap/' /etc/nsswitch.conf

    systemctl enable --now slapd
    systemctl enable --now nslcd
    systemctl enable --now nscd

    LDAP_PASSWORD_HASH=$(slappasswd -s "${CARME_LDAP_SERVER_PW}")

    printf "dn: olcDatabase={1}mdb,cn=config\nchangetype: modify\nreplace: olcRootPW\nolcRootPW: ${LDAP_PASSWORD_HASH}\n" | ldapmodify -Q -Y EXTERNAL -H ldapi:///

    USER_PASSWORD_HASH=$(slappasswd -s "${CARME_PASSWORD_USER}")

    if [[ ! $(ldapfinger ${CARME_USER}) ]]; then
      ldapinit -s
      ldapaddgroup ${CARME_GROUP}
      ldapadduser ${CARME_USER} ${CARME_GROUP}
      ldapsetpasswd ${CARME_USER} ${USER_PASSWORD_HASH}
      systemctl restart nslcd
    fi

    LDAP_SERVER_IP=$(hostname -I | awk '{print $1}')

    # compute-nodes -----------------------------
    for COMPUTE_NODE in ${CARME_NODE_LIST[@]}; do
      ssh -t ${COMPUTE_NODE} "systemctl enable --now nslcd"
      ssh -t ${COMPUTE_NODE} "systemctl enable --now nscd"

      ssh -t ${COMPUTE_NODE} "sed -i 's|^uri .*|uri ldap://${LDAP_SERVER_IP}|' /etc/nslcd.conf"
      ssh -t ${COMPUTE_NODE} "sed -i 's/^base .*/base dc=nodomain/' /etc/nslcd.conf"
      ssh -t ${COMPUTE_NODE} "sed -i '/^passwd:.*ldap/b; /^passwd:/ s/\\s*$/ ldap/' /etc/nsswitch.conf"
      ssh -t ${COMPUTE_NODE} "sed -i '/^group:.*ldap/b; /^group:/ s/\\s*$/ ldap/' /etc/nsswitch.conf"
      ssh -t ${COMPUTE_NODE} "sed -i '/^shadow:.*ldap/b; /^shadow:/ s/\\s*$/ ldap/' /etc/nsswitch.conf"

      ssh -t ${COMPUTE_NODE} "systemctl restart nslcd"
    done
  fi
fi

if [[ ${CARME_LDAP} == "yes" ]]; then
  log "ldap successfully installed."
else
  log "ldap successfully configured."
fi
