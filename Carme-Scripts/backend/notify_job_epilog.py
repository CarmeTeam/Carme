#!/usr/bin/python3

#-----------------------------------------------------------------------------------------------------------------------------------
# notifies to the head node that the job has stopped execution
#
# usage: python notify_job_epilog.py SLURM_JOB_ID SLURM_JOB_USER CARME_BACKEND_SERVER CARME_BACKEND_PORT
# Copyright (C) 2019 by Philipp Reusch (ITWM)
#-----------------------------------------------------------------------------------------------------------------------------------

import sys
import rpyc

ec = 137

SLURM_JOB_ID = sys.argv[1]
SLURM_JOB_USER = sys.argv[2]
CARME_BACKEND_SERVER = sys.argv[3]
CARME_BACKEND_PORT = sys.argv[4]

keyfile = "/opt/Carme/Carme-Scripts/backend/slurmctld.key"
certfile = "/opt/Carme/Carme-Scripts/backend/slurmctld.crt"

conn = rpyc.ssl_connect(CARME_BACKEND_SERVER, CARME_BACKEND_PORT, keyfile=keyfile, certfile=certfile)
res = conn.root.exposed_JobEpilog(SLURM_JOB_ID, SLURM_JOB_USER)

print("notify_job_epilog:", res)

if isinstance(res, int):
  ec = res

sys.exit(ec)
