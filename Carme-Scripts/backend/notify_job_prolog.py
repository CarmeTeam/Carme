#!/usr/bin/python

#-----------------------------------------------------------------------------------------------------------------------------------
# notifies to the head node that the job has started execution
#
# usage: python notify_job_prolog.py SLURM_JOB_ID SLURM_JOB_USER CARME_BACKEND_SERVER CARME_BACKEND_PORT
# Copyright (C) 2019 by Philipp Reusch (ITWM)
#-----------------------------------------------------------------------------------------------------------------------------------

import sys
import rpyc

SLURM_JOB_ID = sys.argv[1]
SLURM_JOB_USER = sys.argv[2]
CARME_BACKEND_SERVER = sys.argv[3]
CARME_BACKEND_PORT = sys.argv[4]

keyfile = "/home/" + SLURM_JOB_USER + "/.carme/" + SLURM_JOB_USER + ".key"
certfile = "/home/" + SLURM_JOB_USER + "/.carme/" + SLURM_JOB_USER + ".crt"

conn = rpyc.ssl_connect(CARME_BACKEND_SERVER, CARME_BACKEND_PORT, keyfile=keyfile, certfile=certfile)
res = conn.root.exposed_JobProlog(SLURM_JOB_ID, SLURM_JOB_USER)
