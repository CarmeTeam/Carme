#!/usr/bin/python
#-----------------------------------------------------------------------------------------------------------------------------------
# notifies to the head node that the job has finished execution
#
# usage: python notify_job_finished.py SLURM_JOBID CARME_BACKEND_SERVER CARME_BACKEND_PORT
# Copyright (C) 2018 by Janis Keuper (ITWM)
#-----------------------------------------------------------------------------------------------------------------------------------

import imp
import sys    
import rpyc  
import os  
                                                                                                                                                                                                        
SLURM_JOBID=sys.argv[1]  
CARME_BACKEND_SERVER=sys.argv[2]
CARME_BACKEND_PORT=sys.argv[3]  

# TODO: DONT do this as a user! 
USER=os.environ['USER']
keyfile="/home/"+USER+"/.carme/"+USER+".key"
certfile="/home/"+USER+"/.carme/"+USER+".crt"   

conn = rpyc.ssl_connect(CARME_BACKEND_SERVER, CARME_BACKEND_PORT, keyfile=keyfile,certfile=certfile) 
res=conn.root.exposed_JobFinished(SLURM_JOBID)         
