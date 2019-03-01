# ---------------------------------------------- 
# Carme
# ----------------------------------------------
# admin.py                                                                                                                                                                     
#                                                                                                                                                                                                            
# see Carme development guide for documentation: 
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#
# Copyright 2019 by Fraunhofer ITWM  
# License: http://open-carme.org/LICENSE.md 
# Contact: info@open-carme.org
# ---------------------------------------------
from django.contrib import admin
from .models import SlurmJobs
from .models import Images
from .models import CarmeMessages
from .models import ClusterStat
from .models import GroupResources
from django.conf import settings

admin.site.site_header = settings.CARME_ADMIN_HEADER
admin.site.site_title = settings.CARME_ADMIN_SITE_NAME
admin.site.index_title = settings.CARME_ADMIN_SITE_INDEX

""" admin view for image db

"""
class ImageAdmin(admin.ModelAdmin):
    list_display = ('image_name', 'image_path', 'image_group',
                    'image_mounts', 'image_comment', 'image_status', 'image_owner')
    list_display_links = ('image_name', 'image_owner')
    search_fields = ('image_name', 'image_group', 'image_owner')
    list_per_page = 25

""" admin view for job db

"""
class SlurmJobAdmin(admin.ModelAdmin):
    list_display = ('frontend','imageName', 'user', 'URL', 'NumNodes', 'NumGPUs', 'comment', 'SLURM_ID',
                    'status', 'EntryNode', 'imageID', 'IP', 'HASH', 'NB_PORT', 'TB_PORT', 'GPUS')
    list_display_links = ('imageName', 'user')
    search_fields = ('imageName', 'user', 'SLURM_ID', 'status', 'EntryNode')
    list_per_page = 25

""" admin view for user messages

"""
class CarmeMessageAdmin(admin.ModelAdmin):
    list_display = ('user','message','color')


""" admin view for from GroupResources

"""
class GroupResourcesAdmin(admin.ModelAdmin):
    list_display = ('group_name','group_partition','group_default','group_max_jobs','group_max_nodes','group_max_gpus_per_node')
    list_display_links = ('group_name','group_partition') 
    search_fields = ('group_name','group_partition','group_default','group_max_jobs','group_max_nodes','group_max_gpus_per_node')
    list_per_page = 25

""" deprecated

"""
class RuningJobAdmin(admin.ModelAdmin):
    list_display = ('user', 'URL', 'UID', 'LDAP_ID', 'start', 'end')

""" admin view for cluster statistics

"""
class StatAdmin(admin.ModelAdmin):
    list_display = ('date', 'free', 'used', 'reserved', 'queued')

admin.site.register(Images, ImageAdmin)
admin.site.register(SlurmJobs, SlurmJobAdmin)
admin.site.register(CarmeMessages, CarmeMessageAdmin)
admin.site.register(ClusterStat, StatAdmin)
admin.site.register(GroupResources, GroupResourcesAdmin)
