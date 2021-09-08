#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Add a new user to LDAP. In order to do that the script tries to determine possible ldap group base using the
# 'objectClass=PosixGroup' feature as filter. If this does not match your LDAP structure you cannot use this script out of
# the box. But it is possible to change this filter by changing the variable 'LDAP_GROUP_CLASS'.
#
# WEBPAGE:   https://carmeteam.github.io/Carme/
# COPYRIGHT: Carme Team @Fraunhofer ITWM
# CONTACT:   dominik.strassel@itwm.fraunhofer.de
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# adjustable parameters ------------------------------------------------------------------------------------------------------------
PATH_TO_SCRIPTS_FOLDER="/opt/Carme/Carme-Scripts"
LDAP_GROUP_CLASS="PosixGroup"
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
if [[ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ]];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  die "'${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh' not found"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# some basic checks before we continue ---------------------------------------------------------------------------------------------
# check if bash is used to execute the script
is_bash

# check if root executes this script
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command grep
check_command getent
check_command awk
check_command ldapsearch
check_command ldapadd
check_command ldappasswd
check_command hostname
#-----------------------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------------------
# needed variables from config
CARME_LDAP_SERVER_IP=$(get_variable CARME_LDAP_SERVER_IP)
CARME_LDAP_DEFAULTPASSWD_FOLDER=$(get_variable CARME_LDAP_DEFAULTPASSWD_FOLDER)
CARME_LDAP_PASSWD_BASESTRING=$(get_variable CARME_LDAP_PASSWD_BASESTRING)
CARME_LDAP_PASSWD_LENGTH=$(get_variable CARME_LDAP_PASSWD_LENGTH)
CARME_LDAP_BIND_DN=$(get_variable CARME_LDAP_BIND_DN)


[[ -z ${CARME_LDAP_SERVER_IP} ]] && die "CARME_LDAP_SERVER_IP not set"
[[ -z ${CARME_LDAP_DEFAULTPASSWD_FOLDER} ]] && die "CARME_LDAP_DEFAULTPASSWD_FOLDER not set"
[[ -z ${CARME_LDAP_PASSWD_BASESTRING} ]] && die "CARME_LDAP_PASSWD_BASESTRING not set"
[[ -z ${CARME_LDAP_PASSWD_LENGTH} ]] && die "CARME_LDAP_PASSWD_LENGTH not set"
[[ -z ${CARME_LDAP_BIND_DN} ]] && die "CARME_LDAP_BIND_DN not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if host is the server hosting ldap -----------------------------------------------------------------------------------------
THIS_NODE_IPS=( "$(hostname -I)" )
[[ ! "${THIS_NODE_IPS[*]}" =~ ${CARME_LDAP_SERVER_IP} ]] && die "this is not the server hosting ldap"
#-----------------------------------------------------------------------------------------------------------------------------------


read -rp "Do you want to add a new user? [y/N] " RESP
echo ""

if [[ "$RESP" = "y" ]];then

  # get date and check if default-passwd-folder exists -----------------------------------------------------------------------------
  LDAP_DATE="$(date +%Y-%m-%d)"
  LDAP_FILENAME="${LDAP_DATE}--${LDAPUSER}.txt"

  [[ -z ${CARME_LDAP_DEFAULTPASSWD_FOLDER} ]] && die "CARME_LDAP_DEFAULTPASSWD_FOLDER not set"
  if [[ ! -d "${CARME_LDAP_DEFAULTPASSWD_FOLDER}" ]];then
    mkdir "${CARME_LDAP_DEFAULTPASSWD_FOLDER}" || die "cannot create ${CARME_LDAP_DEFAULTPASSWD_FOLDER}"
  fi
  #---------------------------------------------------------------------------------------------------------------------------------


  # ask for the LDAP admin password ------------------------------------------------------------------------------------------------
  read -s -rp "enter the LDAP admin password: " LDAP_ADMIN_PASSWORD
  echo ""
  #---------------------------------------------------------------------------------------------------------------------------------


  # determine avsailable LDAP posix groups on the system ---------------------------------------------------------------------------
  mapfile -t LDAP_GROUP_BASE < <(ldapsearch -x -D "${CARME_LDAP_BIND_DN}" "objectClass=${LDAP_GROUP_CLASS}" -w "${LDAP_ADMIN_PASSWORD}" | grep "dn:" | awk -F'dn: ' '{ print $2 }')
  echo ""
  #---------------------------------------------------------------------------------------------------------------------------------


  # check if the 'objectClass=PosixGroup' is used or exit if not -------------------------------------------------------------------
  [[ ${#LDAP_GROUP_BASE[@]} -eq 0 ]] && die "ERROR: cannot determine possible ldap group base using 'objectClass=${LDAP_GROUP_CLASS}'"
  #---------------------------------------------------------------------------------------------------------------------------------


  # list all ldap group bases found on your system ---------------------------------------------------------------------------------
  echo "possible ldap group bases found on your system:"
  COUNTER=0
  for GROUP_BASE in "${LDAP_GROUP_BASE[@]}";do
    COUNTER=$((++COUNTER))
    echo "(${COUNTER}) ${GROUP_BASE}"
  done
  echo ""
  #---------------------------------------------------------------------------------------------------------------------------------


  # ask which LDAP group base should be used ---------------------------------------------------------------------------------------
  read -rp "enter number (1-${#LDAP_GROUP_BASE[@]}) of ldap groub base you want to use: " INPUT_NUMBER
  echo ""
  LDAP_GROUP_BASE_NUMBER="$((--INPUT_NUMBER))"
  #---------------------------------------------------------------------------------------------------------------------------------


  # ask for new ldap user name -----------------------------------------------------------------------------------------------------
  read -rp "enter new user name: " LDAPUSER
  echo ""

  # check is username contains uppercase characters
  [[ $LDAPUSER =~ [A-Z] ]] && die "uppercase usernames are not allowed"

  # check if username is empty
  [[ -z "$LDAPUSER" ]] && die "empty usernames are not allowed"

  # check if user allready exists
  USEREXISTS=$(id -u "${LDAPUSER}" > /dev/null 2>&1; echo $?)
  [[ "${USEREXISTS}" = "0" ]] && die "cannot create ${LDAPUSER} as it already exists"
  #---------------------------------------------------------------------------------------------------------------------------------


  # determine highest user-id and set user-id --------------------------------------------------------------------------------------
  LDAP_STRING=$(getent passwd | awk -F : '$3>h{h=$3;u=$1}END{print h ":" u}')
  LDAP_HIGHUID=${LDAP_STRING%%:*}
  NEXTUID=$((LDAP_HIGHUID+1))
  #---------------------------------------------------------------------------------------------------------------------------------


  # determine ldap group-id --------------------------------------------------------------------------------------------------------
  LDAP_GROUP="${LDAP_GROUP_BASE[${LDAP_GROUP_BASE_NUMBER}]%%,*}"
  LDAP_GROUP="${LDAP_GROUP##*=}"
  GROUPID="$(getent group | grep "${LDAP_GROUP}" | awk -F: '{ print $3}')"
  #---------------------------------------------------------------------------------------------------------------------------------


  # create random default password -------------------------------------------------------------------------------------------------
  LDAP_PASSWD=$(head /dev/urandom | tr -dc "${CARME_LDAP_PASSWD_BASESTRING}" | head -c "${CARME_LDAP_PASSWD_LENGTH}")
  [[ -z ${LDAP_PASSWD} ]] && die "LDAP_PASSWD not set"
  #---------------------------------------------------------------------------------------------------------------------------------


  # print what we have -------------------------------------------------------------------------------------------------------------
echo "new user credentials:
dn:               uid=${LDAPUSER},${LDAP_GROUP_BASE[${LDAP_GROUP_BASE_NUMBER}]}
objectClass:      top
objectClass:      account
objectClass:      posixAccount
objectclass:      shadowAccount
userid:           ${LDAPUSER}
cn:               ${LDAPUSER}
uidNumber:        ${NEXTUID}
gidNumber:        ${GROUPID}
homeDirectory:    /home/${LDAPUSER}
loginShell:       /bin/bash
default password: ${LDAP_PASSWD}
"
  #---------------------------------------------------------------------------------------------------------------------------------


  # ask if the values are correct before we continue -------------------------------------------------------------------------------
  read -rp "do you want to create a new user with these credentials? [y|N] " NEW_USER_CHECK
  echo ""

  if [[ "${NEW_USER_CHECK}" == "y" ]];then

    # add new user to LDAP database ------------------------------------------------------------------------------------------------
ldapadd -v -x -D "${CARME_LDAP_BIND_DN}" -w "${LDAP_ADMIN_PASSWORD}"  << EOF
dn:uid=${LDAPUSER},${LDAP_GROUP_BASE[${LDAP_GROUP_BASE_NUMBER}]}
objectClass:top
objectClass:account
objectClass:posixAccount
objectclass:shadowAccount
userid:${LDAPUSER}
cn:${LDAPUSER}
uidNumber:${NEXTUID}
gidNumber:${GROUPID}
homeDirectory:/home/${LDAPUSER}
loginShell:/bin/bash
EOF

ldappasswd -D "${CARME_LDAP_BIND_DN}" "uid=${LDAPUSER},${LDAP_GROUP_BASE[${LDAP_GROUP_BASE_NUMBER}]}" -w "${LDAP_ADMIN_PASSWORD}" -s "${LDAP_PASSWD}"
    #-------------------------------------------------------------------------------------------------------------------------------


    # pipe new user data to file ---------------------------------------------------------------------------------------------------
    echo "user: ${LDAPUSER}
userid: ${NEXTUID}
default password: ${LDAP_PASSWD}
created: ${LDAP_DATE}
groubid: ${GROUPID}
" >> "${CARME_LDAP_DEFAULTPASSWD_FOLDER}/${LDAP_FILENAME}"

    echo "user credentials stored in"
    echo "${CARME_LDAP_DEFAULTPASSWD_FOLDER}/${LDAP_FILENAME}"
    echo ""
    #-------------------------------------------------------------------------------------------------------------------------------


    # create user home -------------------------------------------------------------------------------------------------------------
    mkdir -vp "/home/${LDAPUSER}" || die "cannot create /home/${LDAPUSER}"
    cp -vr "/etc/skel/." "/home/${LDAPUSER}" || die "cannot copy /etc/skel/. to /home/${LDAPUSER}"
    mkdir -vp "/home/${LDAPUSER}/.config/carme" || die "cannot create /home/${LDAPUSER}/.config/carme"
    mkdir -vp "/home/${LDAPUSER}/.local/share/carme" || die "cannot create /home/${LDAPUSER}/.local/share/carme"
    mkdir -vp "/home/${LDAPUSER}/.ssh" || die "cannot create /home/${LDAPUSER}/.ssh"
    chown -v -R "${NEXTUID}":"${GROUPID}" "/home/${LDAPUSER}" || die "cannot change ownership of /home/${LDAPUSER}"
    echo ""
    #-------------------------------------------------------------------------------------------------------------------------------


    # reminder -----------------------------------------------------------------------------------------------------------------------
    echo "remember to"
    echo "           - add '${LDAPUSER}' to the scheduler"
    echo "           - create a user certificate for '${LDAPUSER}'"
    #---------------------------------------------------------------------------------------------------------------------------------

  else

    echo "bye bye..."

  fi

else

  echo "bye bye..."

fi
