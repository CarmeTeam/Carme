#!/usr/bin/env python
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

import os
import sys
import ssl
import ldap3
import MySQLdb
import traceback
import subprocess

from shlex import quote
from rpyc import Service
from datetime import datetime
from rpyc.utils.server import ThreadedServer
from rpyc.utils.authenticators import SSLAuthenticator

tables = {
    "notifications": "carme_carmemessage",
    "jobs": "carme_slurmjob"
}

queries = {
    # send_notification
    "insert_notification": "INSERT INTO `{}` (user, message, color) VALUES (%s, %s, %s)".format(tables["notifications"]),
    # is_job_owner
    "select_job_by_id_and_user": "SELECT * FROM `{}` WHERE slurm_id = %s AND user = %s LIMIT 1".format(tables["jobs"]),
    # exposed_update
    "select_job_status_by_id": "SELECT status FROM `{}` WHERE slurm_id = %s LIMIT 1".format(tables["jobs"]),
    "update_job_details": "UPDATE `{}` SET ip = %s, url_suffix = %s, nb_port = %s, tb_port = %s, ta_port = %s, gpu_ids = %s WHERE slurm_id = %s".format(tables["jobs"]),
    "update_queued_job_status_running": "UPDATE `{}` SET status = \"running\" WHERE slurm_id = %s AND status = \"queued\"".format(tables["jobs"]),
    # exposed_scheduled # in development
    # exposed_cancelled
    "update_job_status_cancelled": "UPDATE `{}` SET status = \"cancelled\" WHERE slurm_id = %s".format(tables["jobs"]),
    # exposed_epilog
    "update_job_status_finished": "UPDATE `{}` SET status = \"finished\" WHERE slurm_id = %s".format(tables["jobs"]),
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
    service = "{path}" '''.format(path=path, entrypoint=entrypoint, middlewares=middlewares_str, host=CARME_FRONTEND_URL)
    #[http.routers.{path}.tls]'''.format(path=path, entrypoint=entrypoint, middlewares=middlewares_str, host=CARME_FRONTEND_URL)

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

    # Note 
        only methods with prefix exposed_ are callable via rpc
    """

    def on_connect(self, conn):
        """called on a new rpc connection
        
        # arguments
            conn: rpyc connection object

        # returns
            nothing
        """
        DB_PORT = int(CARME_DB_DEFAULT_PORT.replace('"', ''))
        self.db = MySQLdb.connect(host=CARME_DB_DEFAULT_NODE, user=CARME_DB_DEFAULT_USER, passwd=CARME_DB_DEFAULT_PASS, db=CARME_DB_DEFAULT_NAME, port=DB_PORT)
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

    def send_notification(self, message, user, color): # in development 
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
            user: job owner username
            slurm_id: slurm job id

        # returns
            true or false whether user is owner or not

        # note
            used by exposed_update
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
        print("before route sucsess")
        print(ip)
        route = proxy_config_str(url_suffix, "https", ip, nb_port, tb_port, ta_port)
        print("before path success")
        path = os.path.join(CARME_PATH_PROXY_ROUTES, "routes", "{}-{}.toml".format(CARME_FRONTEND_ID, job_id))
        print("before ssh")
        print(CARME_FRONTEND_NODE)
        com = "ssh {node} 'cat > {path} << EOF\n{content}\nEOF'".format(node=CARME_FRONTEND_NODE, path=path, content=route)

        ret = os.system(com)

        if ret != 0:
            print("error exposed_update - route file could not be created for job {}".format(job_id))
            return ret

        # update job details
        try:
            cur = self.db.cursor()
            cur.execute(queries["update_job_details"], (ip, url_suffix, nb_port, tb_port, ta_port, gpu_ids, job_id,))

            self.db.commit()  
        except:
            self.db.rollback()

            print("error exposed_update - sql statement update_job_details failed")
            traceback.print_exc()

            return 1

        # set job running, if queued
        try:
            cur = self.db.cursor()
            cur.execute(queries["update_queued_job_status_running"], (job_id,))

            self.db.commit()  
        except:
            self.db.rollback()

            try:
                cur = self.db.cursor()
                cur.execute(queries["select_job_status_by_id"], (job_id,))

                job = cur.fetchone()

                if not job or job[0] is not "cancelled":
                    print("error exposed_update - sql statement update_queued_job_status_running failed")
                    traceback.print_exc()

                    return 1
            except:
                print("error exposed_update - sql statement select_job_status_by_id failed")
                traceback.print_exc()

                return 1
            
        return 0

    def exposed_schedule(self, user, home, image, flags, partition, acc_num, nod_num, job_name, acc_name):
        """schedule a new job via the batch system

        # note 
            only requests from the frontend are expected

        # arguments
            user: username
            home: home directory
            image: /path/to/image 
            flags: singularity flags
            partition: slurm partition to be used
            acc_num num_gpus: number of accelerators per node to be used
            nod_num num_nodes: number of nodes per job
            job_name name: job name 
            acc_name gpu_type: name of the accelerator we want to use

        # returns
            batch system job id
        """
        
        print("schedule job {} for user {}".format(job_name, user))

        if self.user != "frontend":
            print("error exposed_schedule - has to be executed by frontend, but user is {}".format(user))
            return 0
        
        # needs to be updated: 1) only handles systems with one kind of accelerator_name per node
        #                      2) only handles nodes with the same main_memory_per_node for each accelerator_name
        #                      3) only handles nodes with the same number of accelerators_name per node
        
        # acc_type
        try:
            cur = self.db.cursor()
            cur.execute("select type from projects_accelerator where (name=%s and node_status=1)", (acc_name,))
            acc_type = cur.fetchone()
        except:
            print("error exposed_schedule - sql statement select type failed")
            traceback.print_exc()

            return 1

        # num_accs_per_node_in_system
        try:
            cur = self.db.cursor()
            cur.execute("select num_per_node from projects_accelerator where (name=%s and node_status=1)", (acc_name,))
            num_accs_per_node_in_system = cur.fetchone()
        except:
            print("error exposed_schedule - sql statement select num_per_node failed")
            traceback.print_exc()

            return 1

        # num_cpus_per_node_in_system
        try:
            cur = self.db.cursor()
            cur.execute("select num_cpus_per_node from projects_accelerator where (name=%s and node_status=1)", (acc_name,))
            num_cpus_per_node_in_system = cur.fetchone()
        except:
            print("error exposed_schedule - sql statement select num_cpus_per_node failed")
            traceback.print_exc()

            return 1

        # main_mem_per_node_in_system
        try:
            cur = self.db.cursor()
            cur.execute("select main_mem_per_node from projects_accelerator where (name=%s and node_status=1)", (acc_name,))
            main_mem_per_node_in_system = cur.fetchone()
        except:
            print("error exposed_schedule - sql statement select main_mem_per_node failed")
            traceback.print_exc()

            return 1

        # validate query
        if num_accs_per_node_in_system  is None or num_cpus_per_node_in_system is None or main_mem_per_node_in_system is None:
            print("error exposed_schedule - num_accs_per_node_in_system, or num_cpus_per_node_in_system or main_mem_per_node_in_system does not exist")

            return 0

        # num_cpus_per_acc_in_system & main_mem_per_acc_in_system
        try:
            num_cpus_per_acc_in_system = num_cpus_per_node_in_system[0] // num_accs_per_node_in_system[0] # rounds down
            main_mem_per_acc_in_system = main_mem_per_node_in_system[0] // num_accs_per_node_in_system[0] # rounds down
        except ZeroDivisionError as e:
            print("error exposed_schedule -  cannot divide by zero, num_accs_per_node_in_system is not expected")

            return 1

        # num_cpus_per_node_in_job & main_mem_per_node_in_job
        num_cpus_per_node_in_job = int(acc_num) * num_cpus_per_acc_in_system
        main_mem_per_node_in_job = int(acc_num) * main_mem_per_acc_in_system
 
        # build sbatch command
        values = {
            'constraints': 'carme',
            'partition': partition,
            'job_name': job_name,
            'nod_num': nod_num,
            'acc_num': acc_num,
            'acc_name': acc_name,
            'cores_per_node': num_cpus_per_node_in_job,
            'mem_per_node': str(main_mem_per_node_in_job) + 'M',
            'log_dir': os.path.join(home, '.local/share/carme/job-log-dir')
        }

        template = "--parsable --constraint=\"{constraints}\" --partition=\"{partition}\" --job-name=\"{job_name}\" --nodes=\"{nod_num}\" --ntasks-per-node=\"{cores_per_node}\" --cpus-per-task=\"1\" --mem=\"{mem_per_node}\" -o \"{log_dir}/%j.out\" -e \"{log_dir}/%j.err\""
        
        # extend sbatch command for specific accelerator type
        if acc_type in ('cpu', 'CPU'):
            pass
        elif acc_type in ('gpu', 'GPU'):
            template += " --gres=\"gpu:{acc_name}:{acc_num}\" --gres-flags=\"enforce-binding\""
        elif acc_type in ('fpga', 'FPGA'):
            pass # in development
        else:
            pass # in development

        params = template.format(**values)

        com = "runuser -u {user} -- bash -l -c 'cd ${{HOME}}; SHELL=/bin/bash sbatch {params} << EOF\n#!/bin/bash\nsrun \"{script}\" \"{image}\" {flags}\nEOF'".format(user=user, params=params, script=os.path.join(CARME_PATH_SCRIPTS, "slurm/job-scripts/slurm.sh"), image=image, flags=quote(flags))

        print(com)

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
            #self.send_notification("Scheduled job {}".format(job_id), user, "#e8be17") # in development
        else:
            print("error exposed_schedule - job {} could not be scheduled for user {}".format(job_name, user))
            #self.send_notification("Error: Scheduling job {} failed! - Please contact your admin.".format(name), user, "red") # in development

        return job_id

    def exposed_cancel(self, job_id, user):
        """cancel the job via the batch system

        # note
            only requests from the frontend are expected

        # arguments
            job_id: id string of the job
            user: username of job owner
        
        # returns
            nothing
        """

        print("cancel job {} for user {}".format(job_id, user))

        if self.user != "frontend":
            print("error exposed_cancel - has to be executed by frontend, but user is {}".format(user))
            return

        # cancel job via batch system
        com = "scancel {}".format(job_id)

        ret = os.system(com)
        
        if ret == 0:
            # set job to cancelled in database
            try:
                cur = self.db.cursor()
                cur.execute("update carme_slurmjob set status=\"cancelled\" where slurm_id=%s", (job_id,))
                # cur.execute(queries["update_job_status_cancelled"], (job_id,))
                self.db.commit()

            except:
                print("error exposed_cancel - sql statement update_job_status_cancelled failed")
                traceback.print_exc()

                return 1


            print("cancelled perfectly job {} for user {}".format(job_id, user))
            #self.send_notification("Cancelled job {}".format(job_id), user, "#e8be17") # in development
        else:
            print("error exposed_cancel - scancel failed for job {} from user {}".format(job_id, user))
            #self.send_notification("Error: Cancelling job {} failed!  - Please contact your admin.".format(job_id), user, "red") # in development

        return ret
    
    def exposed_prolog(self, job_id, user):
        """job prolog

        # arguments
            job_id: job id
            user: job owner username
        
        # returns
            exit code, success = 0
        """
        
        print("prolog for job {}".format(job_id))
        #self.send_notification("Started job {}".format(job_id), user, "#64FA3C") # in development

        return 0

    def exposed_epilog(self, job_id, user):
        """job epilog

        # arguments
            job_id: job id
            user: job owner username
        
        # returns
            exit code, success = 0
        """

        print("epilog for job {}".format(job_id))

        # delete route file
        base_path = os.path.join(CARME_PATH_PROXY_ROUTES, "routes")
        toml_path = os.path.join(base_path, "{}-{}.toml".format(CARME_FRONTEND_ID, job_id))
        com = "ssh {node} 'rm -f {toml_path} && touch {base_path}'".format(node=CARME_FRONTEND_NODE, toml_path=toml_path, base_path=base_path)
        
        ret = os.system(com)

        if ret != 0:
            print("error exposed_epilog - deleting route for job {} from user {} failed".format(job_id, user))

        # delete job from database
        try:
            cur = self.db.cursor()
            cur.execute(queries["update_job_status_finished"], (job_id,))

            self.db.commit()
            #self.send_notification("Finished job {}".format(job_id), user, "#00B5FF") # in development
        except:
            print("error exposed_epilog - sql statement update_job_status_finished failed")
            traceback.print_exc()

            self.db.rollback() 
            #self.send_notification("Error: Epilog for job {} failed! - Please contact your admin.".format(job_id), user, "red") # in development

        return 0

    def exposed_change_password(self, user, user_name, password): # in development
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
            s = ldap3.Server(CARME_LDAP_SERVER_IP, get_info=ldap3.ALL)
            c = ldap3.Connection(s, user=CARME_LDAP_BIND_DN, password=CARME_LDAP_SERVER_PW)
            
            c.bind()
            c.modify(user, {'userPassword': [(ldap3.MODIFY_REPLACE, password)]})
            c.unbind()

            print("password changed for user {}".format(user))

            ret = True
        except:
            print("error exposed_change_password - changing ldap password for user {} failed".format(user_name))
            traceback.print_exc()

        return ret

def start():
    import sys
    import argparse
    from os import R_OK
    from os import access
    from os.path import isfile
    from importlib import metadata
    VERSION = metadata.version('carme_backend')

    # Initiate the parser
    parser = argparse.ArgumentParser(description='Backend server for the high performance computing ai suite Carme.')
    parser.add_argument('-V', '--version', action='version', version=f'%(prog)s v{VERSION}')
    parser.add_argument('config', type=str, help='path to carme configuration file')

    # Read arguments from the command line
    args = parser.parse_args()

    if not isfile(args.config) or not access(args.config, R_OK):
        raise Exception("Carme configuration file doesn't exist or is not readable.")

    # import needed variables from CarmeConfig
    from importlib.machinery import SourceFileLoader
    SourceFileLoader('CarmeConfig', args.config).load_module()

    from CarmeConfig import CARME_DB_DEFAULT_USER, CARME_DB_DEFAULT_PASS, CARME_DB_DEFAULT_NAME, CARME_DB_DEFAULT_NODE, CARME_DB_DEFAULT_PORT
    from CarmeConfig import CARME_FRONTEND_ID, CARME_FRONTEND_URL, CARME_FRONTEND_NODE, CARME_BACKEND_PORT
    from CarmeConfig import CARME_PATH_PROXY_ROUTES, CARME_PATH_SCRIPTS, CARME_PATH_BACKEND
    from CarmeConfig import CARME_LDAP_SERVER_IP, CARME_LDAP_SERVER_PW, CARME_LDAP_BIND_DN

    global CARME_DB_DEFAULT_USER, CARME_DB_DEFAULT_PASS, CARME_DB_DEFAULT_NAME, CARME_DB_DEFAULT_NODE, CARME_DB_DEFAULT_PORT
    global CARME_FRONTEND_ID, CARME_FRONTEND_URL, CARME_FRONTEND_NODE, CARME_BACKEND_PORT
    global CARME_PATH_PROXY_ROUTES, CARME_PATH_SCRIPTS, CARME_PATH_BACKEND
    global CARME_LDAP_SERVER_IP, CARME_LDAP_SERVER_PW, CARME_LDAP_BIND_DN

    auth = SSLAuthenticator(os.path.join(CARME_PATH_BACKEND, "SSL/backend.key"), 
                            os.path.join(CARME_PATH_BACKEND, "SSL/backend.crt"),
                            cert_reqs=ssl.CERT_REQUIRED, ca_certs=os.path.join(CARME_PATH_BACKEND, "SSL/backend.crt"))
    server = ThreadedServer(Backend, port=CARME_BACKEND_PORT,
                            authenticator=auth, protocol_config={'allow_all_attrs': True})

    print("starting backend on port {}".format(CARME_BACKEND_PORT))
    server.start()
