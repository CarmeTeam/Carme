# ---------------------------------------------- 
# Carme
# ----------------------------------------------
# models.py                                                                                                                                                                     
#                                                                                                                                                                                                            
# see Carme development guide for documentation: 
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#
# Copyright 2019 by Fraunhofer ITWM  
# License: http://open-carme.org/LICENSE.md 
# Contact: info@open-carme.org
# ---------------------------------------------
from django.db import models
from datetime import datetime
from datetime import datetime

""" User Messages

"""
class CarmeMessages(models.Model):
    user = models.CharField(max_length=64)
    message = models.CharField(max_length=512, default='message')
    color = models.CharField(max_length=16, default='gray')

""" deprecated

"""
class RuningJobs(models.Model):
    UID = models.IntegerField(default=9999999)
    LDAP_ID = models.IntegerField(default=9999999)
    user = models.CharField(max_length=64)
    URL = models.CharField(max_length=512)
    start = models.DateTimeField('date published')
    end = models.DateTimeField('date published')
    NumNodes = models.IntegerField(default=1)
    NumGPUs = models.IntegerField(default=1)
    comment = models.CharField(max_length=512, default='link to imge')
    SLURM_ID = models.IntegerField(default=9999999)
    status = models.CharField(max_length=64, default='running')

    def __str__(self):
        return self.URL

""" cluster usage statistics

"""
class ClusterStat(models.Model):
    date = models.DateTimeField(default=datetime.now, blank=True)
    free = models.IntegerField(default=0)
    used = models.IntegerField(default=0)
    reserved = models.IntegerField(default=0)
    queued = models.IntegerField(default=0)

""" list of running and queued jobs

"""
class SlurmJobs(models.Model):
    LDAP_ID = models.IntegerField(default=9999999)
    user = models.CharField(max_length=64)
    URL = models.CharField(max_length=512, default='queued')
    NumNodes = models.IntegerField(default=1)
    NumGPUs = models.IntegerField(default=1)
    comment = models.CharField(max_length=512, default='open image')
    SLURM_ID = models.IntegerField(default=9999999)
    status = models.CharField(max_length=64, default='queued')
    EntryNode = models.CharField(max_length=5012, default='1.1.1.1.1')
    imageID = models.IntegerField(default=0)
    # ID for multi node jobs
    IP = models.CharField(max_length=512, default='1.1.1.1.1')
    HASH = models.CharField(max_length=512, default='aaaaaaaaa')
    # TODO: add entry point table and use relative base_port offset
    NB_PORT = models.IntegerField(default=8080)
    TB_PORT = models.IntegerField(default=6666)
    #TA_PORT = models.IntegerField(default=7777)
    GPUS = models.CharField(max_length=64, default='non')
    imageName = models.CharField(max_length=128, default='no image')
    jobName = models.CharField(max_length=128, default='job')
    frontend = models.CharField(max_length=64, default='main') 
    def __str__(self):
        return self.URL

""" user status 
    # NOTE: currently not used

"""
class UserStatus(models.Model):
    UID = models.IntegerField(default=9999999)
    LDAP_ID = models.IntegerField(default=9999999)
    PWstatus = models.IntegerField(default=0)

""" messages
    # NOTE: deprecated
"""
class Messages(models.Model):
    text = models.CharField(max_length=512)

""" avalable images

"""
class Images(models.Model):
    image_name = models.CharField(max_length=128)
    image_path = models.CharField(max_length=512)
    image_group = models.CharField(max_length=64)
    image_mounts = models.CharField(max_length=512)
    image_comment = models.CharField(
        max_length=1024, default="image description")
    image_status = models.CharField(max_length=128, default="active")
    image_owner = models.CharField(max_length=64, default="admin")

""" image instances

"""
class ImageInstances(models.Model):
    instance_name = models.CharField(max_length=128)
    instance_image = models.CharField(max_length=128)  # =image_name
    instance_mounts = models.CharField(max_length=512)
    instance_comment = models.CharField(
        max_length=1024, default="instance description")
    instance_group = models.CharField(max_length=64)
    instance_owner = models.CharField(max_length=64)


class GroupResources(models.Model):
    group_name = models.CharField(max_length=128)
    group_partition = models.CharField(max_length=128)
    group_default = models.BooleanField() 
    group_max_jobs = models.IntegerField()
    group_max_nodes = models.IntegerField()
    group_max_gpus_per_node = models.IntegerField()

# -- external Slurm DB (read only)
# python manage.py inspectdb --database slurm

class CarmeJobTable(models.Model):
    job_db_inx = models.BigAutoField(primary_key=True)
    mod_time = models.BigIntegerField()
    deleted = models.IntegerField()
    account = models.TextField(blank=True, null=True)
    admin_comment = models.TextField(blank=True, null=True)
    array_task_str = models.TextField(blank=True, null=True)
    array_max_tasks = models.PositiveIntegerField()
    array_task_pending = models.PositiveIntegerField()
    cpus_req = models.PositiveIntegerField()
    derived_ec = models.PositiveIntegerField()
    derived_es = models.TextField(blank=True, null=True)
    exit_code = models.PositiveIntegerField()
    job_name = models.TextField()
    id_assoc = models.PositiveIntegerField()
    id_array_job = models.PositiveIntegerField()
    id_array_task = models.PositiveIntegerField()
    id_block = models.TextField(blank=True, null=True)
    id_job = models.PositiveIntegerField()
    id_qos = models.PositiveIntegerField()
    id_resv = models.PositiveIntegerField()
    id_wckey = models.PositiveIntegerField()
    id_user = models.PositiveIntegerField()
    id_group = models.PositiveIntegerField()
    kill_requid = models.IntegerField()
    mem_req = models.BigIntegerField()
    nodelist = models.TextField(blank=True, null=True)
    nodes_alloc = models.PositiveIntegerField()
    node_inx = models.TextField(blank=True, null=True)
    partition = models.TextField()
    priority = models.PositiveIntegerField()
    state = models.PositiveIntegerField()
    timelimit = models.PositiveIntegerField()
    time_submit = models.BigIntegerField()
    time_eligible = models.BigIntegerField()
    time_start = models.BigIntegerField()
    time_end = models.BigIntegerField()
    time_suspended = models.BigIntegerField()
    gres_req = models.TextField()
    gres_alloc = models.TextField()
    gres_used = models.TextField()
    wckey = models.TextField()
    track_steps = models.IntegerField()
    tres_alloc = models.TextField()
    tres_req = models.TextField()

    class Meta:
        managed = False
        db_table = 'carme_job_table'
        unique_together = (('id_job', 'id_assoc', 'time_submit'),)


class CarmeAssocTable(models.Model):
    creation_time = models.BigIntegerField()
    mod_time = models.BigIntegerField()
    deleted = models.IntegerField()
    is_def = models.IntegerField()
    id_assoc = models.AutoField(primary_key=True)
    user = models.TextField()
    acct = models.TextField()
    partition = models.TextField()
    parent_acct = models.TextField()
    lft = models.IntegerField()
    rgt = models.IntegerField()
    shares = models.IntegerField()
    max_jobs = models.IntegerField(blank=True, null=True)
    max_submit_jobs = models.IntegerField(blank=True, null=True)
    max_tres_pj = models.TextField()
    max_tres_pn = models.TextField()
    max_tres_mins_pj = models.TextField()
    max_tres_run_mins = models.TextField()
    max_wall_pj = models.IntegerField(blank=True, null=True)
    grp_jobs = models.IntegerField(blank=True, null=True)
    grp_submit_jobs = models.IntegerField(blank=True, null=True)
    grp_tres = models.TextField()
    grp_tres_mins = models.TextField()
    grp_tres_run_mins = models.TextField()
    grp_wall = models.IntegerField(blank=True, null=True)
    def_qos_id = models.IntegerField(blank=True, null=True)
    qos = models.TextField()
    delta_qos = models.TextField()

    class Meta:
        managed = False
        db_table = 'carme_assoc_table'
        unique_together = (('user', 'acct', 'partition'),)
