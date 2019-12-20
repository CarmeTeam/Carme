#!/usr/bin/python
#-----------------------------------------------------------------------------------------------------------------------------------
# deletes job in job table
#
# usage: python rm_jobDB_entry.py SLURM_JOBID 
# Copyright (C) 2018 by Janis Keuper (ITWM)
#-----------------------------------------------------------------------------------------------------------------------------------

import sys
import rpyc
import os

SLURM_JOBID=sys.argv[1]
CARME_BACKEND_SERVER=sys.argv[2]
CARME_BACKEND_PORT=sys.argv[3]

USER=os.environ['USER']
USER_HOME=os.environ['HOME']
keyfile=USER_HOME+"/.config/carme/"+USER+".key"
certfile=USER_HOME+"/.config/carme/"+USER+".crt"

conn = rpyc.ssl_connect(CARME_BACKEND_SERVER, CARME_BACKEND_PORT, keyfile=keyfile,certfile=certfile)
res=conn.root.exposed_jobEndTrigger(SLURM_JOBID)

