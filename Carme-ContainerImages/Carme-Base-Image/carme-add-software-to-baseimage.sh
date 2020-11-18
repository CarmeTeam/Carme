#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to 
#
# Copyright (C) 2018 by Dr. Dominik Straßel
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


# check if bash is used to execute the script --------------------------------------------------------------------------------------
[[ ! "$BASH_VERSION" ]] && die "This is a bash-script. Please use bash to execute it!"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if root executes this script -----------------------------------------------------------------------------------------------
[[ ! "$(whoami)" = "root" ]] && die "you need root privileges to run this script"
#-----------------------------------------------------------------------------------------------------------------------------------

read -rp "Do you want to create a new singularity recipe file? [y/N] " RESP
echo ""
if [ "$RESP" = "y" ]; then

  read -rp "Type the file-name of the extensions you want to add? (without .txt) " NEW_INSTALL
  echo ""

  [[ ! $NEW_INSTALL =~ ^[0-9]{4}-0[1-9]|1[0-2]-0[1-9]|[1-2][0-9]|3[0-1]_[a-fA-F]$ ]] && die "your file should have to form YYYY-MM-DD_text.txt"

  FILENAME="${NEW_INSTALL}.txt"
  FILENAME_TMP="tmp.txt"
  NEW_FILENAME="Carme-Baseimage_${NEW_INSTALL}.recipe"

  cp CARME-Base-Image.recipe "${NEW_FILENAME}" || die "cannot copy CARME-Base-Image.recipe to ${NEW_FILENAME}"
  cp "${FILENAME}" "${FILENAME_TMP}" || die "cannot copy ${FILENAME} to ${FILENAME_TMP}"

  sed -i 's/^/    /' "${FILENAME_TMP}"

  STRING_TO_REPLACE="#post-replace"
  sed -i -e "/$STRING_TO_REPLACE/r $FILENAME_TMP" -e "/$STRING_TO_REPLACE/d" "${NEW_FILENAME}"
  rm "${FILENAME_TMP}" || die "cannot remove ${FILENAME_TMP}"

else

  echo "Bye Bye..."

fi
