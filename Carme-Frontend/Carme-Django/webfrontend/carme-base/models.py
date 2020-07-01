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

import os
from django.db import models
from datetime import datetime
from importlib.machinery import SourceFileLoader

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SourceFileLoader('CarmeConfigFrontend', BASE_DIR + '/../../../CarmeConfig.frontend').load_module()
from CarmeConfigFrontend import CARME_SLURM_ClusterName

""" User Messages

"""
class CarmeMessages(models.Model):
    user = models.CharField(max_length=64)
    message = models.CharField(max_length=512, default='message')
    color = models.CharField(max_length=16, default='gray')

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
    user = models.CharField(max_length=64)
    num_nodes = models.IntegerField(default=1)
    num_gpus = models.IntegerField(default=1)
    slurm_id = models.IntegerField(default=0)
    status = models.CharField(max_length=64, default='queued')
    ip = models.CharField(max_length=512, default='1.1.1.1')
    url_suffix = models.CharField(max_length=512, default='unknown')
    nb_port = models.IntegerField(default=0)
    tb_port = models.IntegerField(default=0)
    ta_port = models.IntegerField(default=0)
    gpu_ids = models.CharField(max_length=64, default='none')
    image_name = models.CharField(max_length=128, default='no image')
    name = models.CharField(max_length=128, default='unknown')
    frontend = models.CharField(max_length=64, default='main')
    gpu_type = models.CharField(max_length=64, default='none')

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
        db_table = str(CARME_SLURM_ClusterName) + '_job_table'
        unique_together = (('id_job', 'id_assoc', 'time_submit'),)
