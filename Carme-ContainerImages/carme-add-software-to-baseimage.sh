#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# script to 
#
# Copyright (C) 2018 by Dr. Dominik Straßel
#-----------------------------------------------------------------------------------------------------------------------------------


SETCOLOR='\033[1;33m'
NOCOLOR='\033[0m'
printf "\n"
#-----------------------------------------------------------------------------------------------------------------------------------

if [ ! $(whoami) = "root" ]; then
    printf "${SETCOLOR}you need root privileges to run this script${NOCOLOR}\n\n"
    exit 137
fi

#-----------------------------------------------------------------------------------------------------------------------------------

read -p "Do you want to create a new singularity recipe file? [y/N] " RESP
if [ "$RESP" = "y" ]; then

    printf "\n"
    read -p "Type the file-name of the extensions you want to add? (without .txt) " NEW_INSTALL

    if [[ ! $NEW_INSTALL =~ ^[0-9]{4}-0[1-9]|1[0-2]-0[1-9]|[1-2][0-9]|3[0-1]_[a-fA-F]$ ]]; then 
      printf "your file should have to form YYYY-MM-DD_text.txt\n"
    # else
    #   printf "wuuhhuuu \(^o^)/\n"
    fi

    FILENAME="${NEW_INSTALL}.txt"
    FILENAME_TMP="tmp.txt"
    NEW_FILENAME="Carme-Baseimage_${NEW_INSTALL}.recipe"

    cp ../Carme-Baseimage.recipe $NEW_FILENAME
    cp $FILENAME $FILENAME_TMP

    sed -i 's/^/    /' $FILENAME_TMP

    STRING_TO_REPLACE="#post-replace"
    sed -i -e "/$STRING_TO_REPLACE/r $FILENAME_TMP" -e "/$STRING_TO_REPLACE/d" $NEW_FILENAME
    rm $FILENAME_TMP

    printf "\n"
    exit 0

else
    printf "${SETCOLOR}Bye Bye...${NOCOLOR}\n\n"
    exit 0
fi
