#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# CARME Administration Command-Line Tool
#
# WEBPAGE:   https://carmeteam.github.io/Carme/
# COPYRIGHT: Carme Team @Fraunhofer ITWM, 2021
# CONTACT:   dominik.strassel@itwm.fraunhofer.de
#-----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# variables ------------------------------------------------------------------------------------------------------------------------

# adjustible variables
CARME_PATH="/opt/Carme"                                                                  # path to carme installation
CARME_CONF_PATH="/etc/carme"                                                             # path to carme config

FRONTEND_SYSTEMD_SERVICE="carme-frontend.service"                                        # frontend systemd service name
PROXY_SYSTEMD_SERVICE="carme-proxy.service"                                              # proxy systemd service name
BACKEND_SYSTEMD_SERVICE="carme-backend.service"                                          # backend systemd service name

CARME_FRONTEND_LOG_FOLDER="/var/log/carme/apache"                                        # folder for the frontend logs on the login node
CARME_PROXY_LOG_FOLDER="/var/log/carme/proxy"                                            # folder for the proxy logs on the login node

CARME_FRONTEND_RUN_FOLDER="/var/run/carme/frontend"                                      # folder for the apache pid file on the login node

CARME_PROXY_ROUTES_FOLDER="/var/lib/carme/proxy/routes"                                  # folder for the proxy routes on the login node


# fixed variables
SSH_COMMAND="ssh -o LogLevel=QUIET"
SCP_COMMAND="scp -o LogLevel=QUIET"
SYNC_SSH="rsync -ah --partial -e ssh"

CARME_CONFIG="${CARME_CONF_PATH}/CarmeConfig"                                            # path to CarmeConfig

CARME_SCRIPTS_PATH="${CARME_PATH}/Carme-Scripts"                                         # path to the carme scripts folder
CARME_BACKEND_PATH="${CARME_PATH}/Carme-Backend"                                         # path to the carme backend folder


CARME_SLURMCTLD_PROLOG_LOGS="/var/log/carme/slurmctld/prolog"
CARME_SLURMCTLD_EPILOG_LOGS="/var/log/carme/slurmctld/epilog"
CARME_SLURMD_PROLOG_LOGS="/var/log/carme/slurmd/prolog"
CARME_SLURMD_EPILOG_LOGS="/var/log/carme/slurmd/epilog"

FRONTEND_CONTAINER_PATH="/opt/Carme/Carme-ContainerImages/Carme-Frontend-Container"
FRONTEND_CONTAINER_PATH_LOGIN="/opt/Carme/Carme-ContainerImages/Carme-Frontend-Container"
FRONTEND_CONTAINER_NAME="frontend.simg"

PROXY_CONTAINER_PATH="/opt/Carme/Carme-ContainerImages/Carme-Proxy-Container"
PROXY_CONTAINER_PATH_LOGIN="/opt/Carme/Carme-ContainerImages/Carme-Proxy-Container"
PROXY_CONTAINER_NAME="proxy.simg"

DJANGO_LOG_FILE="django.log"
APACHE_LOG_FILE="error.log"
PROXY_LOG_FILE="traefik.log"
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
if [[ -f "${CARME_SCRIPTS_PATH}/carme-basic-bash-functions.sh" ]];then
  source "${CARME_SCRIPTS_PATH}/carme-basic-bash-functions.sh"
else
  die "'carme-basic-bash-functions.sh' not found in '${CARME_SCRIPTS_PATH}'"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if bash is used to execute the script --------------------------------------------------------------------------------------
is_bash
#-----------------------------------------------------------------------------------------------------------------------------------


# check if root executes this script -----------------------------------------------------------------------------------------------
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command grep
check_command ssh
check_command scp
check_command hostname
check_command systemctl
#-----------------------------------------------------------------------------------------------------------------------------------


# import the needed variables from CarmeConfig -------------------------------------------------------------------------------------
CARME_HEADNODE_NAME=$(get_variable CARME_HEADNODE_NAME)
CARME_LOGINNODE_NAME=$(get_variable CARME_LOGINNODE_NAME)
CARME_NODES_LIST=$(get_variable CARME_NODES_LIST)
CARME_VERSION=$(get_variable CARME_VERSION)

[[ -z ${CARME_HEADNODE_NAME} ]] && die "CARME_HEADNODE_NAME not set"
[[ -z ${CARME_LOGINNODE_NAME} ]] && die "CARME_LOGINNODE_NAME not set"
[[ -z ${CARME_NODES_LIST} ]] && die "CARME_NODES_LIST not set"
[[ -z ${CARME_VERSION} ]] && die "CARME_VERSION not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if node is headnode --------------------------------------------------------------------------------------------------------
[[ "$(hostname -s)" != "${CARME_HEADNODE_NAME}" ]] && die "This is not the headnode (${CARME_HEADNODE_NAME}) defined in your CARME config."
#-----------------------------------------------------------------------------------------------------------------------------------


# define help message --------------------------------------------------------------------------------------------------------------
function print_help (){
  echo "CARME Administration Command-Line Tool

Webpage: https://carmeteam.github.io/Carme/
Version: ${CARME_VERSION}

Usage: carme-manager [arguments]

Arguments:
  --reset-config-file                           copy the CarmeConfig.repo to '/etc/carme/CarmeConfig' and backup an already existing
                                                config to '/etc/carme/CarmeConfig.bak'
  --create-config-files                         creates the different CarmeConfig files (*.backend, *.frontend, *.node)
                                                (CarmeConfig has to exist)
  --deploy-config-files                         deploy the different CarmeConfig files (*.backend, *.frontend, *.node)
                                                (CarmeConfig has to exist)

  --copy-files-to-compute-nodes                 copy the compute node files from the central CARME installation on the headnode to all
                                                the compute nodes that are listed in the CarmeConfig file

  --start-backend-service                       start the backend service (on the headnode)
  --stop-backend-service                        stop the backend service (on the headnode)
  --status-backend-service                      get the status of the backend service (on the headnode)

  --build-frontend-image                        build a new frontend singularity container (stored on the headnode)
  --copy-frontend-image                         copy the frontend singularity container to the login node
  --start-frontend-service                      start the frontend singularity container service (on the login node)
  --stop-frontend-service                       stop the frontend singularity container service (on the login node)
  --status-frontend-service                     get the status of the frontend singularity container service (on the login node)

  --build-proxy-image                           build a new proxy singularity container (stored on the headnode)
  --copy-proxy-image                            copy the proxy singularity container to the login node
  --start-proxy-service                         start the frontend singularity container service (on the login node)
  --stop-proxy-service                          stop the frontend singularity container service (on the login node)
  --status-proxy-service                        get the status of the frontend singularity container service (on the login node)

  --carme-restart                               restart backend and web frontend
  --carme-full-restart                          restart proxy, backend and web frontend

  --show-frontend-django-log                    view the latest 'django.log' file located at the login node
  --show-frontend-apache-log                    view the latest apache 'error.log' file located at the login node
  --show-proxy-log                              view the latest traefik log file located at the login node

  --list-slurmctld-prolog-logs                  list all availabe slurmctld prolog logs
  --show-slurmctld-prolog-log JOB_ID            show the slurmctld prolog log of a specific job
  --list-slurmctld-epilog-logs                  list all availabe slurmctld epilog logs
  --show-slurmctld-epilog-log JOB_ID            show the slurmctld epilog log of a specific job

  --list-slurmd-prolog-logs NODE_NAME           list all availabe slurmd prolog logs on a given node
  --show-slurmd-prolog-log NODE_NAME JOB_ID     show the slurmd prolog log of a specific job (executed on a specific node)
  --list-slurmd-epilog-logs NODE_NAME           list all availabe slurmd epilog logs on a given node
  --show-slurmd-epilog-log NODE_NAME JOB_ID     show the slurmd epilog log of a specific job (executed on a specific node)

  --ldap-add-user                               add a user to LDAP (interactive)
  --ldap-change-user-pw                         change the ldap password of a user to a specific value (interactive)
  --ldap-reset-user-pw USER (USER2)             reset the ldap password of a user to a random value (interactive)
                                                (multiple users separated by 'space')

  --slurm-add-user                              add a user to the SLURM DB (interactive)
  --slurm-modify-user                           modify entries of a specific SLURM user (interactive)
  --slurm-delete-user                           delete a user from the SLURM DB (interactive)

  --create-mgmt-certs                           create new certificates for backend, frontend and slurm communication
  --create-user-certs                           create new user certificates for carme (interactive)
  --create-single-user-cert USER                create new user certificates for carme (command line mode)

  -h or --help                                  print this help and exit
  --version                                     print the CARME version and exit
"
  exit 0
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define argument list for bash completion -----------------------------------------------------------------------------------------
function print_arglist () {
  arg_list=( "-h" "--help" "--version" "--reset-config-file" "--create-config-files" "--deploy-config-files" "--copy-files-to-compute-nodes" "--start-backend-service" "--stop-backend-service" "--status-backend-service" "--build-frontend-image" "--copy-frontend-image" "--start-frontend-service" "--stop-frontend-service" "--status-frontend-service" "--build-proxy-image" "--copy-proxy-image" "--start-proxy-service" "--stop-proxy-service" "--status-proxy-service" "--carme-restart" "--carme-full-restart" "--ldap-add-user" "--ldap-change-user-pw" "--ldap-reset-user-pw" "--slurm-add-user" "--slurm-modify-user" "--slurm-delete-user" "--create-mgmt-certs" "--create-user-certs" "--create-single-user-cert" "--show-frontend-django-log" "--show-frontend-apache-log" "--show-proxy-log" "--list-slurmd-prolog-logs" "--list-slurmd-epilog-logs" "--show-slurmd-prolog-log" "--show-slurmd-epilog-log" "--list-slurmctld-prolog-logs" "--show-slurmctld-prolog-log" "--list-slurmctld-epilog-logs" "--show-slurmctld-epilog-log")

  echo "${arg_list[@]}"

  return 0
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define functions -----------------------------------------------------------------------------------------------------------------

function reset_config_file () {
# copy the CarmeConfig.repo to /etc/carme and if there exists an old CamreConfic copy it to a backup file

  if [[ -f "${CARME_CONFIG}" ]];then
  mv "${CARME_CONFIG}" "${CARME_CONFIG}.bak"
  echo "WARNING: old CarmeConfig stored as '${CARME_CONFIG}.bak'"
  echo ""
  fi

  cp "${CARME_PATH}/CarmeConfig.repo" "${CARME_CONFIG}"
  echo ""
  echo "WARNING: CarmeConfig was reset to repo state. Remember to fill in the new config according to your setup"
  echo "         and to create new *.backend, *.frontend, *.node configs."

  return 0
}



function create_configs () {
# creates the different CarmeConfig files (*.backend, *.frontend, *.node)
#                                         (CarmeConfig has to exist)

  bash "${CARME_SCRIPTS_PATH}/management/create-deploy-carmeconfig.sh" --create
  return 0
}


function deploy_configs () {
# deploys the different CarmeConfig files (*.backend, *.frontend, *.node)
#                                         (CarmeConfig has to exist)

  bash "${CARME_SCRIPTS_PATH}/management/create-deploy-carmeconfig.sh" --deploy

  return 0
}


function copy_files_to_compute_nodes () {
# copy files to the compute nodes

  local NODE

  for NODE in ${CARME_NODES_LIST}; do
    echo "${NODE}: create '${CARME_PATH}' and subfolders"
    ${SSH_COMMAND} "${NODE}" -t "mkdir -p ${CARME_SCRIPTS_PATH}/slurm/job-scripts"
    ${SSH_COMMAND} "${NODE}" -t "mkdir -p ${CARME_SCRIPTS_PATH}/frontend"
    ${SSH_COMMAND} "${NODE}" -t "mkdir -p ${CARME_SCRIPTS_PATH}/maintenance"

    echo "${NODE}: copy computenode files"
    ${SYNC_SSH} "${CARME_PATH}/LICENSE" "${CARME_PATH}/LICENSE"
    ${SYNC_SSH} "${CARME_SCRIPTS_PATH}/InsideContainer/" "${NODE}:${CARME_SCRIPTS_PATH}/InsideContainer"
    ${SYNC_SSH} "${CARME_SCRIPTS_PATH}/slurm/job-scripts/slurm.sh" "${NODE}:${CARME_SCRIPTS_PATH}/slurm/job-scripts/slurm.sh"
    ${SYNC_SSH} "${CARME_SCRIPTS_PATH}/slurm/job-scripts/slurm-prolog-scripts/" "${NODE}:${CARME_SCRIPTS_PATH}/slurm/job-scripts/slurm-prolog-scripts"
    ${SYNC_SSH} "${CARME_SCRIPTS_PATH}/slurm/job-scripts/slurm-epilog-scripts/" "${NODE}:${CARME_SCRIPTS_PATH}/slurm/job-scripts/slurm-epilog-scripts"
    ${SYNC_SSH} "${CARME_SCRIPTS_PATH}/frontend/alter_jobDB_entry.py" "${NODE}:${CARME_SCRIPTS_PATH}/frontend/alter_jobDB_entry.py"
    ${SYNC_SSH} "${CARME_SCRIPTS_PATH}/maintenance/carme-empty-trash.sh" "${NODE}:${CARME_SCRIPTS_PATH}/frontend/carme-empty-trash.sh"
  done

  return 0
}


function start_backend () {
# start the backend service (on the headnode)

  systemctl start "${BACKEND_SYSTEMD_SERVICE}"

  return 0
}


function start_backend () {
# stop the backend service (on the headnode)

  systemctl stop "${BACKEND_SYSTEMD_SERVICE}"

  return 0
}


function status_backend () {
# get the status of the backend service (on the headnode)

  systemctl --no-pager -l status "${BACKEND_SYSTEMD_SERVICE}"

  return 0
}

${NODE}
function build_frontend_image () {
# build a new frontend image and backup the previous one (stored on the headnode)

  bash "${CARME_SCRIPTS_PATH}/management/carme-build-frontend-proxy-container.sh" --frontend

  return 0
}


function copy_frontend_image () {
# copy the frontend singularity container to the login node

  local CONTAINER_NAME="${FRONTEND_CONTAINER_NAME}"
  local CONTAINER_PATH="${FRONTEND_CONTAINER_PATH}"
  local CONTAINER_PATH_LOGIN="${FRONTEND_CONTAINER_PATH_LOGIN}"

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "mkdir -p ${HELPER_PATH}"
  ${SSH_COMMAND} "${CONTAINER_PATH}/${CONTAINER_NAME}" "${CARME_LOGINNODE_NAME}:${CONTAINER_PATH_LOGIN}/${CONTAINER_NAME}"

  return 0
}


function start_frontend_image () {
# start the frontend singularity container service (on the login node)

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "mkdir -p ${CARME_FRONTEND_LOG_FOLDER}"
  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "mkdir -p ${CARME_FRONTEND_RUN_FOLDER}"
  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "mkdir -p ${CARME_PROXY_ROUTES_FOLDER}"
  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "systemctl start ${FRONTEND_SYSTEMD_SERVICE}"

  return 0
}


function stop_frontend_image () {
# stop the frontend--reset-config singularity container service (on the login node)

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "systemctl stop ${FRONTEND_SYSTEMD_SERVICE}"

  return 0
}


function status_frontend_image () {
# get the status of the frontend singularity container service (on the login node)

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "systemctl --no-pager -l status ${FRONTEND_SYSTEMD_SERVICE}"

  return 0
}


function build_proxy_image () {
# build a new proxy image and backup the previous one (stored on the headnode)

  bash "${CARME_SCRIPTS_PATH}/management/carme-build-frontend-proxy-container.sh" --proxy

  return 0
}


function copy_proxy_image () {
# copy the proxy singularity container to the login node

  local CONTAINER_NAME="${PROXY_CONTAINER_NAME}"
  local CONTAINER_PATH="${PROXY_CONTAINER_PATH}"
  local CONTAINER_PATH_LOGIN="${PROXY_CONTAINER_PATH_LOGIN}"

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "mkdir -p ${HELPER_PATH}"
  ${SCP_COMMAND} "${CONTAINER_PATH}/${CONTAINER_NAME}" "${CARME_LOGINNODE_NAME}:${CONTAINER_PATH_LOGIN}/${CONTAINER_NAME}"

  return 0
}


function start_proxy_image () {
# start the proxy singularity container service (on the login node)

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "mkdir -p ${CARME_PROXY_LOG_FOLDER}"
  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "mkdir -p ${CARME_PROXY_ROUTES_FOLDER}"
  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "systemctl start ${PROXY_SYSTEMD_SERVICE}"

  return 0
}


function stop_proxy_image () {
# stop the proxy singularity container service (on the login node)

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "systemctl stop ${PROXY_SYSTEMD_SERVICE}"

  return 0
}


function status_proxy_image () {
# get the status of the proxy singularity container service (on the login node)

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "systemctl --no-pager -l status ${PROXY_SYSTEMD_SERVICE}"

  return 0
}


function show_django_log () {
# view the latest 'django.log' file located at the login node

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "less ${CARME_FRONTEND_LOG_FOLDER}/${DJANGO_LOG_FILE}"

  return 0
}


function show_apache_log () {
# view the latest apache 'error.log' file located at the login node

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "less ${CARME_FRONTEND_LOG_FOLDER}/${APACHE_LOG_FILE}"

  return 0
}


function show_proxy_log () {
# view the latest apache 'error.log' file located at the login node

  ${SSH_COMMAND} "${CARME_LOGINNODE_NAME}" -t "less ${CARME_PROXY_LOG_FOLDER}/${PROXY_LOG_FILE}"

  return 0
}


function list_slurmctld_prolog_logs () {
# list all availabe slurmctld prolog logs

  /bin/ls --color=never -lahv "${CARME_SLURMCTLD_PROLOG_LOGS}"/*log | less

  return 0
}


function show_slurmctld_prolog_log () {
# show the slurmctld prolog log of a specific job

  local JOB_ID="${1}"

  [[ -z "${1}" ]] && die "you did not specified a jobID"

  less "${CARME_SLURMCTLD_PROLOG_LOGS}/${JOB_ID}.log"

  return 0
}


function list_slurmctld_epilog_logs () {
# list all availabe slurmctld prolog logs

  /bin/ls --color=never -lahv "${CARME_SLURMCTLD_EPILOG_LOGS}"/*log | less

  return 0
}


function show_slurmctld_epilog_log () {
# show the slurmctld epilog log of a specific job

  local JOB_ID="${1}"

  [[ -z "${1}" ]] && die "you did not specified a jobID"

  less "${CARME_SLURMCTLD_EPILOG_LOGS}/${JOB_ID}.log"

  return 0
}


function list_slurmd_prolog_logs () {
# list all availabe slurmd prolog log on a given node

  local NODE_NAME="${1}"

  [[ -z "${1}" ]] && die "you did not specified a hostname"
  ${SSH_COMMAND} "${NODE_NAME}" -t "/bin/ls --color=never -lahv ${CARME_SLURMD_PROLOG_LOGS}/*log | less"

  return 0
}


function list_slurmd_epilog_logs () {
# list all availabe slurmd prolog log on a given node

  local NODE_NAME="${1}"

  [[ -z "${1}" ]] && die "you did not specified a hostname"
  ${SSH_COMMAND} "${NODE_NAME}" -t "/bin/ls --color=never -lahv ${CARME_SLURMD_EPILOG_LOGS}/*log | less"

  return 0
}


function show_slurmd_prolog_log () {
# show the prolog log of a specific job (executed on a specific node)

  local NODE_NAME="${1}"
  local JOB_ID="${2}"

  [[ -z "${1}" ]] && die "you did not specified a hostname"
  [[ -z "${2}" ]] && die "you did not specified a jobID"

  ${SSH_COMMAND} "${NODE_NAME}" -t "less ${CARME_SLURMD_PROLOG_LOGS}/${JOB_ID}.log"

  return 0
}


function show_slurmd_epilog_log () {
# show the epilog log of a specific job (executed on a specific node)

  local NODE_NAME="${1}"
  local JOB_ID="${2}"

  [[ -z "${1}" ]] && die "you did not specified a hostname"
  [[ -z "${2}" ]] && die "you did not specified a jobID"

  ${SSH_COMMAND} "${NODE_NAME}" -t "less ${CARME_SLURMD_EPILOG_LOGS}/${JOB_ID}.log"

  return 0
}


function ldap_add_user () {
# add a user to ldap

  bash "${CARME_SCRIPTS_PATH}/ldap/carme-ldap-add-user.sh"

  return 0
}


function ldap_change_user_password () {
# change the ldap password of a user

  bash "${CARME_SCRIPTS_PATH}/ldap/carme-ldap-change-user-pw.sh"

  return 0
}


function ldap_reset_user_password () {
# reset the ldap password of a user to a random value (interactive)
# (multiple users separated by 'space')

  [[ -z "${*}" ]] && die "'--ldap-reset-user-pw' needs an additional argument - USER (USER2)"

  bash "${CARME_SCRIPTS_PATH}/ldap/carme-ldap-reset-user-pw.sh" "${@}"

  return 0
}


function slurm_add_user () {
# add user to slurm db

  bash "${CARME_SCRIPTS_PATH}/slurm/mgmt-scripts/carme-slurm-add-user.sh"

  return 0
}


function slurm_modify_user () {
# modify entries of a specific slurm user

  bash "${CARME_SCRIPTS_PATH}/slurm/mgmt-scripts/carme-slurm-modify-user.sh"

  return 0
}


function slurm_delete_user () {
# delete a user from the SLURM DB

  bash "${CARME_SCRIPTS_PATH}/slurm/mgmt-scripts/carme-slurm-delete-user.sh"

  return 0
}


function create_mgmt_certs () {
# create new certificates for backend, frontend and slurm communication

  bash "${CARME_SCRIPTS_PATH}/management/carme-create-mgmt-certs.sh"

  return 0
}


function create_user_certs () {
# create new user certificates for carme (interactive mode)

  bash "${CARME_BACKEND_PATH}/SSL/create-and-deploy-user-certs.sh"

  return 0
}


function create_user_certs_cl () {
# create new user certificates for carme (command line mode)

  [[ -z "${1}" ]] && die "'--create-single-user-cert' needs an additional argument - USER"

  bash "${CARME_BACKEND_PATH}/SSL/create-and-deploy-user-certs--single-user.sh" "${1}"

  return 0
}


function print_version () {
# print the carme version

  echo "Carme ${CARME_VERSION}"

  return 0
}
#-----------------------------------------------------------------------------------------------------------------------------------


# main -----------------------------------------------------------------------------------------------------------------------------
if [[ ${#} -eq 0 ]];then

  print_help

else

  while [[ ${#} -gt 0 ]];do
    KEY="${1}"
    case ${KEY} in
     -h|--help)
       print_help
       shift
     ;;
     --reset-config-file)
       reset_config_file
       shift
     ;;
     --create-config-files)
       create_configs
       shift
     ;;
     --deploy-config-files)
       deploy_configs
       shift
     ;;
     --copy-files-to-compute-nodes)
       copy_files_to_compute_nodes
       shift
     ;;
     --start-backend-service)
       start_backend
       shift
     ;;
     --stop-backend-service)
       stop_backend
       shift
     ;;
     --status-backend-service)
       status_backend
       shift
     ;;
     --build-frontend-image)
       build_frontend_image
       shift
     ;;
     --copy-frontend-image)
       copy_frontend_image
       shift
     ;;
     --start-frontend-service)
       start_frontend_image
       shift
     ;;
     --stop-frontend-service)
       stop_frontend_image
       shift
     ;;
     --status-frontend-service)
       status_frontend_image
       shift
     ;;
     --build-proxy-image)
       build_proxy_image
       shift
     ;;
     --copy-proxy-image)
       copy_proxy_image
       shift
     ;;
     --start-proxy-service)
       start_proxy_image
       shift
     ;;
     --stop-proxy-service)
       stop_proxy_image
       shift
     ;;
     --status-proxy-service)
       status_proxy_image
       shift
     ;;
     --carme-restart)
       stop_frontend_image
       stop_backend
       start_backend
       start_frontend_image
       shift
     ;;
     --carme-full-restart)
       stop_frontend_image
       stop_backend
       stop_proxy_image
       start_proxy_image
       start_backend
       start_frontend_image
       shift
     ;;
     --show-frontend-django-log)
       show_django_log
       shift
     ;;
     --show-frontend-apache-log)
       show_apache_log
       shift
     ;;
     --show-proxy-log)
       show_proxy_log
       shift
     ;;
     --list-slurmctld-prolog-logs)
       list_slurmctld_prolog_logs
       shift
     ;;
     --show-slurmctld-prolog-log)
       shift
       show_slurmctld_prolog_log "${1}"
       shift
     ;;
     --list-slurmctld-epilog-logs)
       list_slurmctld_epilog_logs
       shift
     ;;
     --show-slurmctld-epilog-log)
       shift
       show_slurmctld_epilog_log "${1}"
       shift
     ;;
     --list-slurmd-prolog-logs)
       list_slurmd_prolog_logs "${2}"
       shift
       shift
     ;;
     --list-slurmd-epilog-logs)
       list_slurmd_epilog_logs "${2}"
       shift
       shift
     ;;
     --show-slurmd-prolog-log)
       shift
       show_slurmd_prolog_log "${1}" "${2}"
       shift
       shift
     ;;
     --show-slurmd-epilog-log)
       shift
       show_slurmd_prolog_log "${1}" "${2}"
       shift
       shift
     ;;
     --ldap-add-user)
       ldap_add_user
       shift
     ;;
     --ldap-change-user-pw)
       ldap_change_user_password
       shift
     ;;
     --ldap-reset-user-pw)
       shift
       ldap_reset_user_password "${@}"
       shift
     ;;
     --slurm-add-user)
       slurm_add_user
       shift
     ;;
     --slurm-modify-user)
       slurm_modify_user
       shift
     ;;
     --slurm-delete-user)
       slurm_delete_user
       shift
     ;;
     --create-mgmt-certs)
       create_mgmt_certs
       shift
     ;;
     --create-user-certs)
       create_user_certs
       shift
     ;;
     --create-single-user-cert)
       USER_NAME="${2}"
       create_user_certs_cl "${USER_NAME}"
       shift
       shift
     ;;
     --version)
       print_version
       shift
     ;;
     arglist)
       print_arglist
       shift
     ;;
     *)
      print_help
      shift
     ;;
   esac
  done

fi
#-----------------------------------------------------------------------------------------------------------------------------------

exit 0
