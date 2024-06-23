#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to import cluster information from SLURM to the CARME DB
#
# WEBPAGE:   https://carmeteam.github.io/Carme/
# COPYRIGHT: Carme Team @Fraunhofer ITWM, 2024
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


# define path to carme installation ------------------------------------------------------------------------------------------------
CARME_DIR="/opt/Carme"
CONF_PATH="/etc/carme"

PATH_TO_SCRIPTS_FOLDER="${CARME_DIR}/Carme-Scripts"

CONFIG_FILE="${CONF_PATH}/CarmeConfig"
FRONTEND_CONFIG="${CONF_PATH}/CarmeConfig.frontend"
NODE_CONFIG="${CONF_PATH}/CarmeConfig.node"
BACKEND_CONFIG="${CONF_PATH}/CarmeConfig.backend"

VARIABLES_PARAMETER_FILE="${PATH_TO_SCRIPTS_FOLDER}/management/variables.conf"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if config file exists ------------------------------------------------------------------------------------------------------
[[ ! -f "${CONFIG_FILE}" ]] && die "carme config not found in '${CONF_PATH}'."
#-----------------------------------------------------------------------------------------------------------------------------------


# source basic bash functions ------------------------------------------------------------------------------------------------------
if [[ -f "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh" ]];then
  source "${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh"
else
  die "'${PATH_TO_SCRIPTS_FOLDER}/carme-basic-bash-functions.sh' not found."
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check if bash is used to execute the script --------------------------------------------------------------------------------------
is_bash
#-----------------------------------------------------------------------------------------------------------------------------------


# check if root executes this script -----------------------------------------------------------------------------------------------
is_root
#-----------------------------------------------------------------------------------------------------------------------------------


# check essential commands ---------------------------------------------------------------------------------------------------------
check_command hostname
check_command scontrol
check_command awk
check_command mysql
#-----------------------------------------------------------------------------------------------------------------------------------


# import the needed variables from CarmeConfig -------------------------------------------------------------------------------------
CARME_DB_USER=$(get_variable CARME_DB_USER)
CARME_DB_PW=$(get_variable CARME_DB_PW)
CARME_DB_DB=$(get_variable CARME_DB_DB)
CARME_HEADNODE_NAME=$(get_variable CARME_HEADNODE_NAME)

[[ -z ${CARME_DB_USER} ]] && die "CARME_DB_USER not set"
[[ -z ${CARME_DB_PW} ]] && die "CARME_DB_PW not set"
[[ -z ${CARME_DB_DB} ]] && die "CARME_DB_DB not set"
[[ -z ${CARME_HEADNODE_NAME} ]] && die "CARME_HEADNODE_NAME not set"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if node is headnode --------------------------------------------------------------------------------------------------------
[[ "$(hostname -s)" != "${CARME_HEADNODE_NAME}" ]] && die "this is not the headnode ('${CARME_HEADNODE_NAME}') specified in '${CONFIG_FILE}'."
#-----------------------------------------------------------------------------------------------------------------------------------


# check if variables file is available ---------------------------------------------------------------------------------------------
[[ ! -f ${VARIABLES_PARAMETER_FILE} ]] && die "'${VARIABLES_PARAMETER_FILE}' not found"
#-----------------------------------------------------------------------------------------------------------------------------------


# set database password -----------------------------------------------------------------------------------------------------
export MYSQL_PWD=${CARME_DB_PW}
#-----------------------------------------------------------------------------------------------------------------------------------


# delete the old accelerator table -------------------------------------------------------------------------------------------------
mysql --user ${CARME_DB_USER} ${CARME_DB_DB} -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_accelerator"
#-----------------------------------------------------------------------------------------------------------------------------------

# create the new accelerator table -------------------------------------------------------------------------------------------------
scontrol show nodes -o | awk '
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
      if (n != 3) {
        printf "ERROR: unknown gres format: NodeName=%s\n", node_name
        next
      }
      type = toks[1]
      name = toupper(toks[2])
      num_per_node = toks[3]
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
  print "name ->", name
  print "type ->", type
  print "num_per_node ->", num_per_node
		print "num_cpus_per_node ->", num_cpus_per_node
		print "main_mem_per_node ->", main_mem_per_node
  print "node_name ->", node_name
  print "node_status ->", node_status
  print ""
  system("mysql --user '${CARME_DB_USER}' '${CARME_DB_DB}' -e \"INSERT INTO projects_accelerator (\\`name\\`, \\`type\\`, \\`num_per_node\\`, \\`num_cpus_per_node\\`, \\`main_mem_per_node\\`, \\`node_name\\`, \\`node_status\\`) VALUES (\\\"" name "\\\", \\\"" type "\\\", \\\"" num_per_node "\\\", \\\"" num_cpus_per_node "\\\", \\\"" main_mem_per_node "\\\", \\\"" node_name "\\\", \\\"" node_status "\\\")\"")
}
'
#-----------------------------------------------------------------------------------------------------------------------------------

# delete the old templatehasaccelerator table --------------------------------------------------------------------------------------
mysql --user ${CARME_DB_USER} ${CARME_DB_DB} -e "SET FOREIGN_KEY_CHECKS = 0; truncate table projects_templatehasaccelerator"
#-----------------------------------------------------------------------------------------------------------------------------------

# create the new templatehasaccelerator table --------------------------------------------------------------------------------------
mysql --user ${CARME_DB_USER} ${CARME_DB_DB} -e "INSERT INTO projects_templatehasaccelerator (\`accelerator_id\`, \`resourcetemplate_id\`) SELECT projects_accelerator.\`id\`,projects_resourcetemplate.\`id\` FROM projects_accelerator JOIN projects_resourcetemplate"
#-----------------------------------------------------------------------------------------------------------------------------------

exit 0
