# ----------------------------------------------
# Carme
# ---------------------------------------------- 
# get_free_gpu_on_host.py - polls backend for GPU allocation 
#
# see Carme development guide for documentation:  
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md   
# * Carme/Carme-Doc/DevelDoc/BackendDocu.md  
# 
# Copyright 2019 by Fraunhofer ITWM   
# License: http://open-carme.org/LICENSE.md   
# Contact: info@open-carme.org 
# ---------------------------------------------

import imp     
import sys
import rpyc
import os


IP=sys.argv[1]
NUM=sys.argv[2]
CARME_BACKEND_SERVER=sys.argv[3]  
CARME_BACKEND_PORT=sys.argv[4]  
USER=os.environ['USER']
keyfile="/home/"+USER+"/.carme/"+USER+".key"
certfile="/home/"+USER+"/.carme/"+USER+".crt"
GPUS="FAIL"
try:
    conn = rpyc.ssl_connect(CARME_BACKEND_SERVER, CARME_BACKEND_PORT, keyfile=keyfile,certfile=certfile) 
    GPUS=conn.root.exposed_getFreeGpuOnHost(str(IP),int(NUM))
    print (GPUS)
except:
    GPUS="FAIL"
    print (GPUS)
