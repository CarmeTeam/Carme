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
from .models import SlurmJob
from .models import Image
from .models import NewsMessage
from .models import CarmeMessage
from .models import ClusterStat
from .models import GroupResource
#from django.conf import settings

admin.autodiscover()
admin.site.enable_nav_sidebar = True

admin.site.site_header = 'EXAMPLETHISISNOTREAL'
#admin.site.site_header = settings.CARME_ADMIN_HEADER
#admin.site.site_title = settings.CARME_ADMIN_SITE_NAME
#admin.site.index_title = settings.CARME_ADMIN_SITE_INDEX

class NewsMessageAdmin(admin.ModelAdmin):
    """ admin view for NewsMessage fields """
    list_display = ('show_custom_message','custom_message','carme_message')
    readonly_fields = ['carme_message']

class ImageAdmin(admin.ModelAdmin):
    """ admin view for ImageAdmin fields """
    list_display = ('name', 'path', 'group',
                    'flags', 'comment', 'status', 'owner')
    list_display_links = ('name', 'owner')
    search_fields = ('name', 'group', 'owner')
    list_per_page = 25

""" admin view for job db

"""
class SlurmJobAdmin(admin.ModelAdmin):
    list_display = ('frontend','image_name', 'user', 'num_nodes', 'num_gpus', 'slurm_id',
                    'status', 'ip', 'url_suffix', 'nb_port', 'tb_port', 'ta_port', 'gpu_ids')
    list_display_links = ('image_name', 'user')
    search_fields = ('image_name', 'user', 'slurm_id', 'status')
    list_per_page = 25

""" admin view for user messages

"""
class CarmeMessageAdmin(admin.ModelAdmin):
    list_display = ('user','message','color')


""" admin view for from GroupResource

"""
class GroupResourceAdmin(admin.ModelAdmin):
    list_display = ('name','partition','default','max_jobs','max_nodes','max_gpus_per_node')
    list_display_links = ('name','partition') 
    search_fields = ('name','partition','default','max_jobs','max_nodes','max_gpus_per_node')
    list_per_page = 25

""" deprecated

"""
class RuningJobAdmin(admin.ModelAdmin):
    list_display = ('user', 'URL', 'UID', 'LDAP_ID', 'start', 'end')

""" admin view for cluster statistics

"""
class StatAdmin(admin.ModelAdmin):
    list_display = ('date', 'free', 'used', 'reserved', 'queued')

admin.site.register(NewsMessage, NewsMessageAdmin)
admin.site.register(Image, ImageAdmin)
admin.site.register(SlurmJob, SlurmJobAdmin)
admin.site.register(CarmeMessage, CarmeMessageAdmin)
admin.site.register(ClusterStat, StatAdmin)
admin.site.register(GroupResource, GroupResourceAdmin)
