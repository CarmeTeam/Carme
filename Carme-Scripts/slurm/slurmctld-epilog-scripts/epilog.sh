#!/bin/sh

#
# notify carme about the job epilog
#

python notify_job_epilog.py SLURM_JOB_ID SLURM_JOB_USER CARME_BACKEND_SERVER CARME_BACKEND_PORT
