# ----------------------------------------------
# Carme
# ----------------------------------------------
# carme_backend.py - the Carme Back End Server
#
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
# * Carme/Carme-Doc/DevelDoc/BackendDocu.md
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# Contact: info@open-carme.org
# ---------------------------------------------

import sys
import os
import ssl
from datetime import datetime
import subprocess
import traceback
import ldap3
import MySQLdb
from rpyc import Service
from rpyc.utils.server import ThreadedServer
from rpyc.utils.authenticators import SSLAuthenticator

# import needed variables from CarmeConfig
from importlib.machinery import SourceFileLoader
SourceFileLoader('CarmeConfig', '/opt/Carme/CarmeConfig.backend').load_module()

from CarmeConfig import CARME_DB_NODE, CARME_DB_USER, CARME_DB_PW, CARME_DB_DB
from CarmeConfig import CARME_BACKEND_PATH, CARME_BACKEND_PORT, CARME_BACKEND_DEBUG
from CarmeConfig import CARME_SCRIPTS_PATH, CARME_PROXY_PATH_BACKEND
from CarmeConfig import CARME_LDAP_SERVER_IP, CARME_LDAP_SERVER_PW, CARME_LDAP_ADMIN, CARME_LDAP_DC1, CARME_LDAP_DC2
from CarmeConfig import CARME_FRONTEND_ID, CARME_URL, CARME_LOGINNODE_NAME, CARME_GPU_DEFAULTS

tables = {
    "notifications": "carme-base_carmemessages",
    "jobs": "carme-base_slurmjobs"
}

queries = {
    "insert_notification": "INSERT INTO `{}` (user, message, color) VALUES (%s, %s, %s)".format(tables["notifications"]),
    "select_job_by_id_and_user": "SELECT * FROM `{}` WHERE slurm_id = %s AND user = %s LIMIT 1".format(tables["jobs"]),
    "select_job_status_by_id": "SELECT status FROM `{}` WHERE slurm_id = %s LIMIT 1".format(tables["jobs"]),
    "update_job": "UPDATE `{}` SET status = \"running\", ip = %s, url_suffix = %s, nb_port = %s, tb_port = %s, ta_port = %s, gpu_ids = %s WHERE slurm_id = %s".format(tables["jobs"]),
    "delete_job": "DELETE FROM `{}` WHERE slurm_id = %s".format(tables["jobs"])
}

def proxy_config_str(url_suffix, entrypoint, ip, nb_port, tb_port, ta_port):
    """returns full config string for traefik route file
    
    # arguments
        url_suffix: url suffix added to entry point paths
        entrypoint: proxy entry point name
        ip: middlewares for this route
        nb_port: jupyterlab port
        tb_port: tensorboard port
        ta_port: theia port

    # returns
        proxy config string
    """

    nb_path = "nb_{}".format(url_suffix)
    tb_path = "tb_{}".format(url_suffix)
    ta_path = "ta_{}".format(url_suffix)
    proxy_auth = "proxy-auth-{}".format(CARME_FRONTEND_ID)

    return "[http.routers]\n" \
           + proxy_router_str(nb_path, entrypoint, [proxy_auth]) + "\n\n" \
           + proxy_router_str(tb_path, entrypoint, [proxy_auth]) + "\n\n" \
           + proxy_router_str(ta_path, entrypoint, ["stripprefix-theia", proxy_auth]) + "\n\n" \
           + "\n\n" \
           + "[http.services]\n" \
           + proxy_service_str(nb_path, ip, nb_port) + "\n\n" \
           + proxy_service_str(tb_path, ip, tb_port) + "\n\n" \
           + proxy_service_str(ta_path, ip, ta_port) + "\n\n" \
           + "\n"

def proxy_router_str(path, entrypoint, middlewares):
    """returns router config string for traefik route file

    # arguments
        path: url path for entry point
        entrypoint: proxy entry point name
        middlewares: middlewares for this route

    # returns
        router config string
    """

    middlewares_str = ", ".join(["\"{}\"".format(mw) for mw in middlewares])

    return '''  [http.routers.{path}]
    entryPoints = ["{entrypoint}"]
    rule = "Host(\`{host}\`) && PathPrefix(\`/{path}\`)"
    middlewares = [{middlewares}]
    service = "{path}"
    [http.routers.{path}.tls]'''.format(path=path, entrypoint=entrypoint, middlewares=middlewares_str, host=CARME_URL)

def proxy_service_str(path, ip, port):
    """returns service config string for traefik route file

    # arguments
        path: url path for entry point
        ip: ip of node running entry point
        port: port of entry point

    # returns
        service config string
    """

    return '''  [[http.services.{path}.loadBalancer.servers]]
    url = "http://{ip}:{port}"'''.format(path=path, ip=ip, port=port)

class Backend(Service):
    """carme backend service class

    # note 
        only methods with prefix exposed_ are callable via rpc
    """

    def on_connect(self, conn):
        """called on a new rpc connection
        
        # arguments
            conn: rpyc connection object

        # returns
            nothing
        """

        self.db = MySQLdb.connect(host=CARME_DB_NODE,  user=CARME_DB_USER,
                                    passwd=CARME_DB_PW,  db=CARME_DB_DB)
        self.user = conn._config['credentials']['subject'][5][0][1]

        endpoint = conn._config['endpoints'][1]
        print("connect of user {user} from {ip}:{port}".format(user=self.user, ip=endpoint[0], port=endpoint[1]))

    def on_disconnect(self, conn):
        """called when a new rpc is terminated

        # arguments
            conn: rpyc connection object

        # returns
            nothing
        """

        endpoint = conn._config['endpoints'][1]
        print("disconnect of user {user} from {ip}:{port}".format(user=self.user, ip=endpoint[0], port=endpoint[1]))

    def send_notification(self, message, user, color): 
        """send a frontend notification to the user

        # arguments
            message: string message
            user: username
            color: color of message

        # returns
            nothing
        """

        notification = "{}: {}".format(datetime.now().strftime("%d/%m/%Y - %H:%M:%S"), message)

        # insert notification into database
        try:
            cur = self.db.cursor()
            cur.execute(queries["insert_notification"], (user, notification, color,))

            self.db.commit()
        except:
            print("error send_notification - sql statement insert_notification failed")
            traceback.print_exc()

            self.db.rollback()

    def is_job_owner(self, user, slurm_id):  
        """checks if a user owns the given job by slurm ID

        # arguments
            user: job owner
            slurm_id: slurm job id

        # returns
            true or false whether user is owner or not
        """

        res = False

        # select job from database
        try:
            cur = self.db.cursor()
            cur.execute(queries["select_job_by_id_and_user"], (slurm_id, user,))

            if cur.fetchone() is None:
                print("no job found for slurm_id {} and user {}".format(slurm_id, user))
            else:
                res = True
        except:
            print("error is_job_owner - sql statement select_job_by_id_and_user failed")
            traceback.print_exc()

        return res

    def exposed_update(self, ip, url_suffix, nb_port, tb_port, ta_port, job_id, url, gpu_ids):
        """updates job data after it has been started by the scheduler

        # arguments
            ip: master node IP
            url_suffix: job hash
            nb_port: jupyterlab port
            tb_port: tensorboard port
            ta_port: theia port
            job_id: job id
            url: full URL
            gpu_ids: num of GPUs
        
        # returns
            exit code, success = 0
        """

        print("update job {} for user {}".format(job_id, self.user))

        # check if user owns job
        if not self.is_job_owner(self.user, job_id):
            return 1

        # create route toml
        route = proxy_config_str(url_suffix, "https", ip, nb_port, tb_port, ta_port)
        path = os.path.join(CARME_PROXY_PATH_BACKEND, "routes", "{}-{}.toml".format(CARME_FRONTEND_ID, job_id))
        com = "ssh {node} 'cat > {path} << EOF\n{content}\nEOF'".format(node=CARME_LOGINNODE_NAME, path=path, content=route)

        ret = os.system(com)

        if ret != 0:
            print("error exposed_update - route file could not be created for job {}".format(job_id))
            return ret

        # update job in database
        try:
            cur = self.db.cursor()
            cur.execute(queries["update_job"], (ip, url_suffix, nb_port, tb_port, ta_port, gpu_ids, job_id,))

            self.db.commit()  
        except: 
            print("error exposed_update - sql statement update_job failed")
            traceback.print_exc()

            self.db.rollback()

        return 0

    def exposed_schedule(self, user, home, image, mounts, partition, num_gpus, num_nodes, name, gpu_type):
        """schedule a new job via the batch system

        # note 
            only requests from the frontend are expected

        # arguments
            user: username
            home: home directory
            image: image to start
            mounts: mount points to be set
            partition: partition to be used
            num_gpus: number of GPUs to be used
            num_nodes: number of nodes
            name: name string, must be unique
            gpu_type: type of the GPU we want to use

        # returns
            batch system job id
        """
        
        print("schedule job {} for user {}".format(name, user))

        if self.user != "frontend":
            print("error exposed_schedule - has to executed by frontend, but user is {}".format(user))
            return 0

        # get cores_per_gpu and mem_per_gpu from config based on gpu_type
        gpu_defaults = CARME_GPU_DEFAULTS.split(" ")
        cores_per_gpu = None
        mem_per_gpu = None

        for default in gpu_defaults:
            if default.startswith(gpu_type):
                default_split = default.split(":")
                cores_per_gpu = int(default_split[1])
                mem_per_gpu = int(default_split[2])
                break
        
        if cores_per_gpu is None or mem_per_gpu is None:
            print("error exposed_schedule - cores per gpu or mem per gpu could not be extracted from CARME_GPU_DEFAULTS")
            return 0

        cores_per_node = int(num_gpus) * cores_per_gpu
        mem_per_node = int(num_gpus) * mem_per_gpu

        # build sbatch command
        values = {
            'constraints': 'carme',
            'partition': partition,
            'job_name': name,
            'num_nodes': num_nodes,
            'gpus_per_node': ':' + num_gpus,
            'gpu_type': ('' if (gpu_type == 'default' or gpu_type == 'cpu') else (':' + gpu_type)),
            'cores_per_node': cores_per_node,
            'mem_per_node': str(mem_per_node) + 'G',
            'log_dir': os.path.join(home, '.local/share/carme/job-log-dir')
        }

        params = "--parsable --constraint=\"{constraints}\" --partition=\"{partition}\" --job-name=\"{job_name}\" --nodes=\"{num_nodes}\" --ntasks-per-node=\"{cores_per_node}\" --cpus-per-task=\"1\" --mem=\"{mem_per_node}\" --gres=\"gpu{gpu_type}{gpus_per_node}\" --gres-flags=\"enforce-binding\" -o \"{log_dir}/%j.out\" -e \"{log_dir}/%j.err\"".format(**values)
        
        com = "runuser -u {user} -- bash -l -c 'cd ${{HOME}}; SHELL=/bin/bash sbatch {params} << EOF\n#!/bin/bash\nsrun \"{script}\" \"{image}\" \"{mounts}\"\nEOF'".format(user=user, params=params, script=os.path.join(CARME_SCRIPTS_PATH, "slurm/job-scripts/slurm.sh"), image=image, mounts=mounts)

        # execute sbatch as user
        proc = subprocess.Popen(com, shell=True, stdout=subprocess.PIPE)

        try:
            proc.wait(10) # wait at most 10 seconds for sbatch to terminate
        except:
            pass # ignore if timeout exceeds, because the returncode won't be 0

        # read job_id from output
        job_id = 0

        if proc.returncode == 0:
            job_id = proc.stdout.read().decode("utf-8").split(";")[0].strip()

            print("scheduled job {} for user {}".format(job_id, user))
            self.send_notification("Scheduled job {}".format(job_id), user, "#e8be17")
        else:
            print("error exposed_schedule - job {} could not be scheduled for user {}".format(name, user))
            self.send_notification("Error: Scheduling job {} failed! - Please contact your admin.".format(name), user, "red")

        return job_id

    def exposed_cancel(self, job_id, user):
        """cancel the job via the batch system

        # note
            only requests from the frontend are exepted

        # arguments
            job_id: id string of the job
            user: username of job owner
        
        # returns
            nothing
        """

        print("cancel job {} for user {}".format(job_id, user))

        if self.user != "frontend":
            print("error exposed_cancel - has to executed by frontend, but user is {}".format(user))
            return

        # cancel job via batch system
        com = "scancel {}".format(job_id)

        ret = os.system(com)
        
        if ret == 0:
            job = None

            # select job from database
            try:
                cur = self.db.cursor()
                cur.execute(queries["select_job_status_by_id"], (job_id,))

                job = cur.fetchone()
            except:
                print("error exposed_cancel - sql statement select_job_status_by_id failed")
                traceback.print_exc()

            # delete job if status is queued
            if job is None:
                print("error exposed_cancel - no job found for slurm_id {} and user {}".format(job_id, user))
            else:
                if job[0] == "queued":
                    try:
                        cur.execute(queries["delete_job"], (job_id,))

                        self.db.commit()
                    except:
                        print("error exposed_cancel - sql statement delete_job failed")
                        traceback.print_exc()

            print("cancelled job {} for user {}".format(job_id, user))
            self.send_notification("Cancelled job {}".format(job_id), user, "#e8be17")
        else:
            print("error exposed_cancel - scancel failed for job {} from user {}".format(job_id, user))
            self.send_notification("Error: Cancelling job {} failed!  - Please contact your admin.".format(job_id), user, "red")

        return ret
    
    def exposed_prolog(self, job_id, user):
        """global prolog for job

        # arguments
            job_id: id of the job
            user: username of job owner
        
        # returns
            exit code, success = 0
        """
        
        print("prolog for job {}".format(job_id))

        self.send_notification("Started job {}".format(job_id), user, "#64FA3C")

        return 0

    def exposed_epilog(self, job_id, user):
        """global epilog for job

        # arguments
            job_id: id of the job
            user: username of job owner
        
        # returns
            exit code, success = 0
        """

        print("epilog for job {}".format(job_id))

        # delete route file
        base_path = os.path.join(CARME_PROXY_PATH_BACKEND, "routes")
        toml_path = os.path.join(base_path, "{}-{}.toml".format(CARME_FRONTEND_ID, job_id))
        com = "ssh {node} 'rm -f {toml_path} && touch {base_path}'".format(node=CARME_LOGINNODE_NAME, toml_path=toml_path, base_path=base_path)
        
        ret = os.system(com)

        if ret != 0:
            print("error exposed_epilog - deleting route for job {} from user {} failed".format(job_id, user))

        # delete job from database
        try:
            cur = self.db.cursor()
            cur.execute(queries["delete_job"], (job_id,))

            self.db.commit()
            self.send_notification("Terminated job {}".format(job_id), user, "#00B5FF")
        except:
            print("error exposed_epilog - sql statement delete_job failed")
            traceback.print_exc()

            self.db.rollback() 
            self.send_notification("Error: Epilog for job {} failed! - Please contact your admin.".format(job_id), user, "red")

        return 0

    def exposed_change_password(self, user, user_name, password):
        """change password for ldap user

        # note
            only requests from the frontend are expected

        # arguments
            user: LDAP user ID
            user_name: user name string
            password: new password to be set
        
        # returns
            true or false, whether password has been changed
        """

        print("change password for user {}".format(user_name))
        
        if self.user != "frontend":
            print("error exposed_change_password has to executed by frontend, but user is {}".format(jobUser))
            return
        
        ret = False # fail by default

        # change password via ldap
        try:
            LDAP_ADMIN_USER = "cn={cn},dc={dc1},dc={dc2}".format(cn=CARME_LDAP_ADMIN, dc1=CARME_LDAP_DC1, dc2=CARME_LDAP_DC2)

            s = ldap3.Server(CARME_LDAP_SERVER_IP, get_info=ldap3.ALL)
            c = ldap3.Connection(s, user=LDAP_ADMIN_USER, password=CARME_LDAP_SERVER_PW)
            
            c.bind()
            c.modify(user, {'userPassword': [(ldap3.MODIFY_REPLACE, password)]})
            c.unbind()

            print("password changed for user {}".format(user))

            ret = True
        except:
            print("error exposed_change_password - changing ldap password for user {} failed".format(user_name))
            traceback.print_exc()

        return ret


if __name__ == "__main__":
    auth = SSLAuthenticator(os.path.join(CARME_BACKEND_PATH, "SSL/backend.key"), os.path.join(CARME_BACKEND_PATH, "SSL/backend.crt"),
                                            cert_reqs=ssl.CERT_REQUIRED, ca_certs=os.path.join(CARME_BACKEND_PATH, "SSL/backend.crt"))
    server = ThreadedServer(Backend, port=CARME_BACKEND_PORT,
                            authenticator=auth, protocol_config={'allow_all_attrs': True})

    print("starting backend on port {}".format(CARME_BACKEND_PORT))
    server.start()
