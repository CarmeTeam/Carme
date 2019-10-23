#!/bin/sh

#
# TODO add some documentary
#

if [[ -z "$LAUNCH_ADDR" ] || [ "$(hostname -i)" == "$LAUNCH_ADDR"]]; then
    echo "I am the launch node and will report that the job started."
    python notify_job_prolog.py SLURM_JOBID CARME_BACKEND_SERVER CARME_BACKEND_PORT
fi
