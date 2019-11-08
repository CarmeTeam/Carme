#!/usr/bin/python
#-----------------------------------------------------------------------------------------------------------------------------------
# updates job in job table
#
# usage: python alter_jobDB_entry.py DBJOBID URL SLURM_JOBID HASH IPADDR NB_PORT TB_PORT GPUS 
# Copyright (C) 2018 by Janis Keuper (ITWM)
#-----------------------------------------------------------------------------------------------------------------------------------
import imp 
import sys 
import rpyc 
import os

DBJOBID=sys.argv[1]
URL=sys.argv[2]
SLURM_JOBID=sys.argv[3]
HASH=sys.argv[4]
IPADDR=sys.argv[5]
NB_PORT=sys.argv[6]
TB_PORT=sys.argv[7]
GPUS=sys.argv[8]
CARME_BACKEND_SERVER=sys.argv[9]           
CARME_BACKEND_PORT=sys.argv[10] 

USER=os.environ['USER']
USER_HOME=os.environ['HOME']
keyfile=USER_HOME+"/.config/carme/"+USER+".key" 
certfile=USER_HOME+"/.config/carme/"+USER+".crt" 

conn = rpyc.ssl_connect(CARME_BACKEND_SERVER, CARME_BACKEND_PORT, keyfile=keyfile,certfile=certfile)
res=conn.root.exposed_userAlterJobDB(IPADDR, HASH, NB_PORT, TB_PORT, SLURM_JOBID, URL, GPUS, DBJOBID )



