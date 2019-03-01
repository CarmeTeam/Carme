#!/bin/bash
ls -l /home/ |grep $1 |  awk -F ' ' '{print $3}' | cut -c1-6 |awk '{print tolower($0)}' |xargs -i -n 1 ./singleUserStat.sh '{}'
