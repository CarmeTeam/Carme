# ---------------------------------------------- 
# Carme
# ----------------------------------------------
# views.py
#
# see Carme development guide for documentation: 
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#
# Copyright 2019 by Fraunhofer ITWM  
# License: http://open-carme.org/LICENSE.md 
# Contact: info@open-carme.org
# ---------------------------------------------


#--------------------------------#
#----- Modules and packages -----#
#--------------------------------#

import numpy as np
from django.http import HttpResponse
from django.template import loader

# Database
from .models import NewsMessage, CarmeMessage, SlurmJob, CarmeJobTable, ClusterStat, GroupResource
from projects.models import ProjectMember, ProjectHasTemplate, TemplateHasAccelerator, Accelerator, TemplateHasImage, ResourceTemplate, Image
from django.db import connections # slurm_acct_db

from django.shortcuts import render
from django.http import HttpResponseRedirect, HttpResponseForbidden, JsonResponse
from .forms import MessageForm, DeleteMessageForm, StartJobForm, StopJobForm, ChangePasswd, JobInfoForm
from django.contrib import messages as dj_messages
#from django.contrib.auth import update_session_auth_hash
from django.contrib.auth import logout as auth_logout
#from django.contrib.auth import login as auth_login
from django.contrib.auth.forms import PasswordChangeForm
from django.contrib.auth.decorators import login_required
from django.contrib.auth.views import LoginView
from django.core.serializers import serialize
from django.core.serializers.json import DjangoJSONEncoder
from django.shortcuts import render, redirect
from django.conf import settings
import os
import time
import random
import string
from datetime import datetime
import rpyc
from django.db.models import Sum
from random import randint
from django.views.generic import TemplateView
import re

# Login
from .forms import LoginForm
#from django.contrib.auth import authenticate, login, logout

# News Card in Dashboard
import misaka

# Chart Card in Dashboard
from django.utils.translation import gettext_lazy as _
from .highcharts.colors import COLORS, next_color
from .highcharts.lines import HighchartPlotLineChartView

# History Card in Dashboard
from django.db.models import Case, Value, When, IntegerField 

# Maintenance
from maintenance_mode.decorators import force_maintenance_mode_off
from maintenance_mode.core import get_maintenance_mode

from importlib.machinery import SourceFileLoader
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
check_password_file = os.path.join(BASE_DIR, 'scripts/check_password.py')

if not os.path.isfile(check_password_file):
    raise Exception("check password module is missing in {}".format(check_password_file))

SourceFileLoader('check_password', check_password_file).load_module()
from check_password import check_password, password_criteria

# 2FA 
from django.shortcuts import redirect, resolve_url
from django.urls import reverse
from base64 import b32encode
from binascii import unhexlify
from two_factor.views.core import SetupView
from django_otp.decorators import otp_required

# 2FA-Admin
from two_factor.admin import AdminSiteOTPRequired
from two_factor.admin import AdminSiteOTPRequiredMixin
from django.contrib.admin import AdminSite
from django.contrib.auth import REDIRECT_FIELD_NAME
from django.contrib.auth.views import redirect_to_login
from django.shortcuts import resolve_url
from two_factor.utils import monkeypatch_method

from two_factor.views.core import LoginView

try:
    from django.utils.http import url_has_allowed_host_and_scheme
except ImportError:
    from django.utils.http import (
        is_safe_url as url_has_allowed_host_and_scheme,
    )

# color dark-mode 
#from django.http import JsonResponse
#from rest_framework.decorators import api_view

#-------------------------------#
#----- classes and methods -----#
#-------------------------------#

# Login
class myLogin(LoginView):
    #redirect to the next page
    def dispatch(self, request, *args, **kwargs):
        if request.user.is_authenticated:
            return HttpResponseRedirect('/')
        else:
            return super(LoginView, self).dispatch(request, *args, **kwargs)
    
myLogin = myLogin.as_view()


# 2FA
class QRSetup(SetupView):
    pass
#    def get_context_data(self, form, **kwargs):
#        context = super().get_context_data(form, **kwargs)
#        if self.steps.current == 'generator':
#            key = self.get_key('generator')
#            rawkey = unhexlify(key.encode('ascii'))
#            b32key = b32encode(rawkey).decode('utf-8')
#            self.request.session[self.session_key_name] = b32key
#            context.update({
#                'QR_URL': reverse(self.qrcode_url),
#                'secret_key': b32key,
#            })
#        elif self.steps.current == 'validation':
#            context['device'] = self.get_device()
#        context['cancel_url'] = resolve_url(settings.LOGIN_REDIRECT_URL)
#        return context

QRSetup = QRSetup.as_view()

# 2FA Admin
class AdminSiteOTPRequiredMixinRedirSetup(AdminSiteOTPRequired):
    def login(self, request, extra_context=None):
        redirect_to = request.POST.get(
            REDIRECT_FIELD_NAME, request.GET.get(REDIRECT_FIELD_NAME)
        )
        # For users not yet verified the AdminSiteOTPRequired.has_permission
        # will fail. So use the standard admin has_permission check:
        # (is_active and is_staff) and then check for verification.
        # Go to index if they pass, otherwise make them setup OTP device.
        if request.method == "GET" and super(
            AdminSiteOTPRequiredMixin, self
        ).has_permission(request):
            # Already logged-in and verified by OTP
            if request.user.is_verified():
                # User has permission
                index_path = reverse("admin:index", current_app=self.name)
            else:
                # User has permission but no OTP set:
                index_path = reverse("two_factor:setup", current_app=self.name)
            return HttpResponseRedirect(index_path)

        if not redirect_to or not url_has_allowed_host_and_scheme(
            url=redirect_to, allowed_hosts=[request.get_host()]
        ):
            redirect_to = resolve_url(settings.LOGIN_REDIRECT_URL)

        return redirect_to_login(redirect_to)

def ldap_username(request):
    return request.user.ldap_user.attrs['uid'][0] #e.g., 'demo-admin'

def ldap_home(request):
    return request.user.ldap_user.attrs['homeDirectory'][0]

# no view, should be a model
def generateChoices(request):
    """generates the list of items for the image drop down menu"""

    group = list(request.user.ldap_user.group_names)[0]
    group_resources = GroupResource.objects.filter(name__exact=group)[0]

    # generate image choices
    image_list = Image.objects.filter(status__exact=1)
    image_choices = set()
    for i in image_list:
        image_choices.add((i.name, i.name))

    # generate num_nodes choices
    node_choices =[]
    for i in range(1, group_resources.max_nodes +1):
        node_choices.append( (str(i), i) )

    # generate num_gpus choices
    gpu_choices = []
    for i in range(1, group_resources.max_gpus_per_node +1):
        gpu_choices.append( (str(i), i) )

    # setting gputype
    gputype=[]
        
    for num in range(len(settings.CARME_GPU_NUM.split())):
        gputype.append(settings.CARME_GPU_NUM.split()[num].split(":")[0])

    # generate gpu_type choices
    gpu_type = [(str(i), i) for i in gputype]

    return node_choices, gpu_choices, sorted(list(image_choices)), gpu_type


def csrf_failure(request, reason=""):
    return redirect("/")             


@login_required(login_url='/account/login') 
def index(request):
    """ dashboard page -> generates user job-list, messages and other interactive features"""
    #if request.user.is_verified():
    if ((get_maintenance_mode()==False and request.user.is_verified()) or 
        (get_maintenance_mode()==True  and request.user.is_verified()  and request.user.is_superuser )):
    
        # logout
        request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

        # ldap
        group = list(request.user.ldap_user.group_names)[0]
        uID = request.user.ldap_user.attrs['uidNumber'][0]
        
        # news card -----------------------------------------------------------------------------------   
        carme_message=os.popen("curl https://www.open-carme.org/message.md").read()
        news_message = NewsMessage.objects.filter()
        if news_message.exists():
            news_message.update(carme_message=carme_message)
            if news_message.values_list('show_custom_message', flat=True)[0] == 1:
                news=misaka.html(news_message.values_list('custom_message', flat=True)[0])
            else:
                news=misaka.html(news_message.values_list('carme_message', flat=True)[0])
        else:
            news_message = NewsMessage.objects.create(carme_message=carme_message)
            news=misaka.html(news_message.values_list('carme_message', flat=True)[0])

        # system card --------------------------------------------------------------------------------
        acceleratorQuery = Accelerator.objects.filter()
    
        accelerator_name = list(acceleratorQuery.order_by('id').values_list('name',flat=True))
        accelerator_name = list({value:"" for value in accelerator_name}) # remove duplicates

        ## top panel--------------------
        accelerator_type = []
        accelerator_ratio = []
        accelerator_name_num_total = []
        accelerator_type_num_total = []
        ## -----------------------------

        ## bottom panel ----------------
        accelerator_node = []
        accelerator_node_status = []
        accelerator_num_per_node = []
        accelerator_num_cpus_per_node = []
        accelerator_main_mem_per_node = []
        ## -----------------------------

        for num in range(len(accelerator_name)):

            ### top panel ---------------------------------------------

            # type
            acceleratorNameQuery=Accelerator.objects.filter(name__exact=accelerator_name[num])
            accelerator_type_single = acceleratorNameQuery.order_by('id').values_list('type',flat=True).first()
            accelerator_type.append(accelerator_type_single)
            # name_total
            accelerator_name_num_per_node = list(acceleratorNameQuery.order_by('id').values_list('num_per_node',flat=True))
            accelerator_name_sum = sum(accelerator_name_num_per_node)
            accelerator_name_num_total.append(accelerator_name_sum)
            # type_total
            acceleratorTypeQuery=Accelerator.objects.filter(type__exact=accelerator_type_single)
            accelerator_type_num_per_node = list(acceleratorTypeQuery.order_by('id').values_list('num_per_node',flat=True))
            accelerator_type_sum = sum(accelerator_type_num_per_node)
            accelerator_type_num_total.append(accelerator_type_sum)
            # ratio name/type
            if accelerator_type_sum == 0:
                accelerator_ratio.append(0)
            else:
                accelerator_ratio.append(round(accelerator_name_sum * 100 / accelerator_type_sum, 1))
            ### -------------------------------------------------------

            ### bottom panel ------------------------------------------

            # node
            accelerator_name_node = list(acceleratorNameQuery.order_by('id').values_list('node_name',flat=True))
            accelerator_node.append(accelerator_name_node)
            # node status
            accelerator_name_node_status = list(acceleratorNameQuery.order_by('id').values_list('node_status',flat=True))
            accelerator_node_status.append(accelerator_name_node_status)
            # num accelerator/node
            accelerator_num_per_node.append(accelerator_name_num_per_node)
            # num cpus/node
            accelerator_name_num_cpus_per_node = list(acceleratorNameQuery.order_by('id').values_list('num_cpus_per_node',flat=True))
            accelerator_num_cpus_per_node.append(accelerator_name_num_cpus_per_node)
            # main mem/node
            accelerator_name_main_mem_per_node = list(acceleratorNameQuery.order_by('id').values_list('main_mem_per_node',flat=True))
            accelerator_main_mem_per_node.append(accelerator_name_main_mem_per_node)
            ### -------------------------------------------------------
            
        ## zipping
        accelerator_zip = zip(accelerator_type,accelerator_ratio,accelerator_name_num_total,accelerator_type_num_total,
                              accelerator_node,accelerator_node_status,accelerator_num_per_node,accelerator_num_cpus_per_node,accelerator_main_mem_per_node)
        
        accelerator_info = []
        for a_type, a_ratio, a_name_num_total, a_type_num_total, a_node, a_node_status, a_num_per_node, a_num_cpus_per_node, a_main_mem_per_node in accelerator_zip:
            a_per_node= []
            a_node_and_status = []
            for stat, acc, cpu, mem in zip(a_node_status,a_num_per_node,a_num_cpus_per_node,a_main_mem_per_node):
                a_per_node.append((stat,acc,cpu,mem))
            for nod, stat in zip(a_node, a_node_status):
                a_node_and_status.append((nod,stat))    

            accelerator_info.append((a_type,a_ratio,a_name_num_total,a_type_num_total,a_node_and_status,a_per_node))

        # jobs card ----------------------------------------------------------------------------------

        ## card header -----------------
        projectQueryActive = ProjectMember.objects.filter(user=request.user, 
                                                          is_approved_by_admin=True,
                                                          is_approved_by_manager=True,
                                                          status='accepted',
                                                          project__is_approved=True)
        project_id = list(projectQueryActive.order_by('id').values_list('project_id',flat=True))
        project_id = list(set(project_id))

        templateQuerySet = ProjectHasTemplate.objects.filter(project_id__in=project_id)
        project_name = list(templateQuerySet.order_by('id').values_list('project__name',flat=True))
        template_name = list(templateQuerySet.order_by('id').values_list('template__name',flat=True))
    
        ### zipping
        project_and_template = list(zip(project_name, template_name))

        ## card body -------------------
        accelerator_per_node_field = []
        accelerator_name_field = []
        accelerator_type_field = []
        image_field = []
        node_field = []
        for num in range(len(template_name)):
            
            #-----------------------------------------------------
            # Filter by template_name TemplateHasAccelerator
            resourceTemplateHasAcceleratorQuery = TemplateHasAccelerator.objects.filter(resourcetemplate__name=template_name[num], accelerator__node_status=1)                      
                                                                                                                                                                        
            # accelerator name list                                                                                                                                                 
            accelerator_name_single = resourceTemplateHasAcceleratorQuery.order_by('id').values_list('accelerator__name',flat=True)                                                 
            accelerator_type_single = resourceTemplateHasAcceleratorQuery.order_by('id').values_list('accelerator__type',flat=True)                                                 
                                                                                                                                                                        
            # max accelerators per node & max nodes per job lists                                                                                                                   
            maxnodes_per_job_per_template = []                                                                                                                                      
            maxaccels_per_node_per_template = []                                                                                                                                    
            
            slurm_accounting_db = 0     
            if slurm_accounting_db == 1:
                cursor = connections['slurm'].cursor()                                                               
                cursor.execute("select max_tres_pj from acheron_assoc_table where user=%s", (request.user.username,))
                rows = cursor.fetchall()
                if rows[0][0].split(",")[0].split("=")[0] == "4": # num nodes
                    maxnodes_per_job = list(rows[0][0].split(",")[0].split("=")[1])
                    maxnodes_per_job = list(map(int, maxnodes_per_job))
                if rows[0][0].split(",")[1].split("=")[0] == "1001": # gres
                    maxaccels_per_node = list(rows[0][0].split(",")[1].split("=")[1])
                    maxaccels_per_node = list(map(int, maxaccels_per_node))                           
            else:
                maxnodes_per_job = resourceTemplateHasAcceleratorQuery.order_by('id').values_list('resourcetemplate__maxnodes_per_job',flat=True) # single value                        
                maxaccels_per_node = resourceTemplateHasAcceleratorQuery.order_by('id').values_list('resourcetemplate__maxaccels_per_node',flat=True) # single value                    
            
            for acc in accelerator_name_single:                                                                                                                                     
                accTemplateHasAcceleratorQuery = TemplateHasAccelerator.objects.filter(resourcetemplate__name=template_name[num], accelerator__name=acc, accelerator__node_status=1)
                # max nodes                                                                                                                                                         
                node_name_per_accelerator_name = list(accTemplateHasAcceleratorQuery.order_by('id').values_list('accelerator__node_name',flat=True))                                
                num_nodes_per_accelerator_name = len(node_name_per_accelerator_name)                                                                                                
                for j in maxnodes_per_job:                                                                                                                                          
                    if j < num_nodes_per_accelerator_name:                                                                                                                          
                        num_nodes_per_accelerator_name = j                                                                                                                          
                maxnodes_per_job_per_template.append(num_nodes_per_accelerator_name)                                                                                                
                                                                                                                                                                        
                # max accelerators                                                                                                                                                  
                num_accels_per_node_per_accelerator_name = list(accTemplateHasAcceleratorQuery.order_by('id').values_list('accelerator__num_per_node',flat=True))                   
                max_accels_per_node_per_accelerator_name = max(num_accels_per_node_per_accelerator_name)                                                                            
                for j in maxaccels_per_node:                                                                                                                                        
                    if j < max_accels_per_node_per_accelerator_name:                                                                                                                
                        max_accels_per_node_per_accelerator_name = j                                                                                                                
                maxaccels_per_node_per_template.append(max_accels_per_node_per_accelerator_name)                                                                                    
            # --------------------------------------------------------                                                                                                              
            # accelerator name, accelerator per node, and node fields                                                                                                               
            accelerator_name_single_filtered = []                                                                                                                                   
            accelerator_type_single_filtered = []                                                                                                                                   
            accelerator_per_node_single_filtered = []                                                                                                                               
            node_single_filtered = []                                                                                                                                               
            for i in range(len(accelerator_name_single)):                                                                                                                           
                if accelerator_name_single[i] not in accelerator_name_single_filtered:                                                                                              
                    accelerator_name_single_filtered.append(accelerator_name_single[i])                                                                                             
                    accelerator_type_single_filtered.append(accelerator_type_single[i])                                                                                             
                    accelerator_per_node_single_filtered.append(maxaccels_per_node_per_template[i])                                                                                 
                    node_single_filtered.append(maxnodes_per_job_per_template[i])                                                                                                   
            accelerator_name_field.append(accelerator_name_single_filtered)                                                                                                         
            accelerator_type_field.append(accelerator_type_single_filtered)                                                                                                         
            accelerator_per_node_field.append(accelerator_per_node_single_filtered)                                                                                                 
            node_field.append(node_single_filtered)
            #------------------------------------------------------
            # image field
            resourceTemplateHasImageQuery = TemplateHasImage.objects.filter(resourcetemplate__name=template_name[num])
            image_name_single = resourceTemplateHasImageQuery.order_by('id').values_list('image__name',flat=True)
            image_field.append(image_name_single)

        jobs_field = zip(accelerator_name_field,accelerator_type_field,accelerator_per_node_field,node_field,image_field,template_name)
        jobs_field_js = zip(accelerator_name_field,accelerator_per_node_field,node_field)


        # chart card
        ## uses accelerator_name
        
        # jobs table
        slurm_list_user = SlurmJob.objects.filter(user__exact=request.user.username, status__in=["queued", "running"])
        myslurmid_active_list = list(slurm_list_user.values_list('slurm_id', flat=True))
        cases_active = [When(id_job=foo, then=sort_order) for sort_order, foo in enumerate(myslurmid_active_list)]
        jobtable_active = CarmeJobTable.objects.filter(id_job__in=myslurmid_active_list).annotate(
        sort_order=Case(*cases_active, output_field=IntegerField())).order_by('sort_order')
        myjobtable_list  = zip( list(slurm_list_user), list(jobtable_active) )
        myjobtable_script = zip ( list(slurm_list_user), list(jobtable_active) )

        # notifications
        message_list = list(CarmeMessage.objects.filter(user__exact=request.user.username).order_by('-id'))[:10] #select only 10 latest messages
    
        ## Projects list
        #projectQuerySetActive = ProjectMember.objects.filter(user=request.user, 
        #                                                      is_approved_by_admin=True, 
        #                                                      is_approved_by_manager=True,
        #                                                      status='accepted',
        #                                                      project__is_approved=True)
        #myprojects = projectQuerySetActive.values('project__name')


        #myprojectlist =[]
        
        ## Template list
        #for item in myprojects:
        #    myprojectlist.append(item['project__name'])
        #mytemplates = ProjectHasTemplate.objects.values('project__name','template__name',
        #                                                'template__maxjobs',
        #                                                'template__maxnodes_per_job',
        #                                                'template__maxaccels_per_node'
        #).filter(project__name__in=myprojectlist)

        
        ## Accelerator list
        #myaccelerators = TemplateHasAccelerator.objects.values('accelerator__name',
        #                                                       'accelerator__type',
        #                                                       'resourcetemplate__name'
        #)
            
        # setting variables gpu card
        #gputype=[]
        #cpupergpu=[]
        #rampergpu=[]
        #gpupernode=[]
        #gputotal=[]
        #for num in range(len(settings.CARME_GPU_DEFAULTS.split())):
        #    gputype.append(settings.CARME_GPU_DEFAULTS.split()[num].split(":")[0])
        #    cpupergpu.append(settings.CARME_GPU_DEFAULTS.split()[num].split(":")[1])
        #    rampergpu.append(settings.CARME_GPU_DEFAULTS.split()[num].split(":")[2])
        
        #for num in range(len(settings.CARME_GPU_NUM.split())):
        #    gpupernode.append(settings.CARME_GPU_NUM.split()[num].split(":")[1])
        #    gputotal.append(settings.CARME_GPU_NUM.split()[num].split(":")[2])
        
        #cpupergpu = list(map(int, cpupergpu))
        #rampergpu = list(map(int, rampergpu))
        #gpupernode = list(map(int, gpupernode))
        #gputotal = list(map(int, gputotal))
        #gpusum = sum(gputotal)
    
        ## loop gpu type chart
        #gpu_loop = range(len(gputype)+1)
    
        # calculate actual stats
        slurm_list = SlurmJob.objects.exclude(status__exact="timeout")
        stats = {
            "used": 0,
            "queued": 0,
            "reserved": 0,
            "free": 0
        }
    
        for j in slurm_list:
            if j.status == "running":
                stats["used"] += j.num_gpus * j.num_nodes
            elif j.status == "queued":
                stats["queued"] += j.num_gpus * j.num_nodes 

        stats["free"] = accelerator_type_num_total[0] - (stats["used"] + stats["reserved"]) # before was gpusum

        # check if stats have to be updated
        try:
            lastStat = ClusterStat.objects.latest('id')
        except:
            lastStat = None
    
        if (lastStat is None or lastStat.free != stats["free"] or lastStat.queued != stats["queued"]):
            ClusterStat.objects.create(date=datetime.now(), free=stats["free"], used=stats["used"], reserved=stats["reserved"], queued=stats["queued"])

        # render template
        context = {
            'myjobtable_list': myjobtable_list,
            'myjobtable_script': myjobtable_script,
            'message_list': message_list,
            #'start_job_form': startForm,
            'CARME_VERSION': settings.CARME_VERSION,
            'DEBUG': settings.DEBUG,
            #'mylist_short': mylist_short, #history
            #'mylist_long': mylist_long,   #history
            #'job_time' : job_time,        #history
            #'gpu_loop' : gpu_loop,
            #'gputype': gputype, #gpucard
            #'cpupergpu': cpupergpu, #gpucard
            #'rampergpu': rampergpu, #gpucard
            #'gpupernode':gpupernode, #gpucard
            #'gputotal':gputotal, #gpucard
            #'gpusum': gpusum, #gpucard
            #'myprojects': myprojects, #projects
            #'mytemplates': mytemplates, #projects
            #'myaccelerators': myaccelerators, #projects
            # news card -------------------------------------------------
            'news': news,
            # system & chart cards --------------------------------------
            'accelerator_info': accelerator_info,
            'accelerator_name': accelerator_name,
            # jobs card -------------------------------------------------
            'project_and_template': project_and_template,
            'jobs_field_js': jobs_field_js,
            'jobs_field': jobs_field,

        }

        return render(request, 'home.html', context)
    
    elif ((get_maintenance_mode()==False and request.user.is_verified()==False)):
        return redirect("two_factor:setup")

    else:
        return redirect("logout")


@login_required(login_url='/account/login')
def admin_all_jobs(request):
    """renders the admin job table"""

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    if request.user.is_superuser:
       # return redirect('/carme/403/') # using external link 403.html

        # get all jobs
        allslurmjobs = SlurmJob.objects.filter(status__in=["queued", "running"]).order_by("-slurm_id")
        allslurmids_list = list(allslurmjobs.values_list("slurm_id", flat=True))
        allcpujobs = CarmeJobTable.objects.filter(id_job__in=allslurmids_list).order_by("-id_job")
        slurm_list = zip ( list(allcpujobs), list(allslurmjobs) )
        # render template
        context = {
            'slurm_list': slurm_list,
            'allcpujobs': allcpujobs,
            'allslurmjobs': allslurmjobs,
        }

    else:
        context = {}

    return render(request, 'admin_all_jobs.html', context)

@force_maintenance_mode_off
def admin_job_table(request):
    """renders the admin job table"""

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    if not request.user.is_authenticated:
        return HttpResponse('Unauthorized', status=401)

    # get all jobs
    allslurmjobs = SlurmJob.objects.filter(status__in=["queued", "running"]).order_by("-slurm_id")
    allslurmids_list = list(allslurmjobs.values_list('slurm_id', flat=True))
    allcpujobs = CarmeJobTable.objects.filter(id_job__in=allslurmids_list).order_by('-id_job')
    slurm_list  = zip( list(allcpujobs), list(allslurmjobs) )
  
    # render template
    context = {
        'slurm_list': slurm_list,
        'allcpujobs': allcpujobs,
        'allslurmjobs': allslurmjobs,
    }

    return render(request, 'blocks/admin_job_table.html', context)

@force_maintenance_mode_off
def job_table(request):
    """renders the user job table and add new slurm jobs after starting"""

    # NOTE: no update of session ex time here!

    if not request.user.is_authenticated:
        return HttpResponse('Unauthorized', status=401)

    # jobs card
    slurm_list_user = SlurmJob.objects.filter(user__exact=request.user.username, status__in=["queued", "running"])
    myslurmid_active_list = list(slurm_list_user.values_list('slurm_id', flat=True))
    cases_active = [When(id_job=foo, then=sort_order) for sort_order, foo in enumerate(myslurmid_active_list)]
    jobtable_active = CarmeJobTable.objects.filter(id_job__in=myslurmid_active_list).annotate(
        sort_order=Case(*cases_active, output_field=IntegerField())).order_by('sort_order')
    myjobtable_list  = zip( list(slurm_list_user), list(jobtable_active) ) 
    myjobtable_script = zip( list(slurm_list_user), list(jobtable_active) )    

    # render template
    context = {
        'myjobtable_list': myjobtable_list,
        'myjobtable_script': myjobtable_script,
    }
    
    return render(request, 'blocks/job_table.html', context)

@login_required(login_url='/account/login')
def start_job(request):
    """starts a new job (handing request to backend)"""
    
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    if request.method == 'POST':

        if not str(request.POST['name']):
            #dj_messages.error(request,'You need to specify a job name.')
            return redirect('/')
        
        num_gpus = int(request.POST['accelerators_pernode'])
        gpus_type = str(request.POST['accelerator']).lower()
        job_name = str(request.POST['name'])[:32]
        template = str(request.POST['template'])
        num_nodes = int(request.POST['nodes']) 
        
        partition = ResourceTemplate.objects.filter(name__exact=template)[0].partition    
        image_db = Image.objects.filter(name__exact=str(request.POST['image']))[0]
        flags = image_db.bind
        image = image_db.path
        name = image_db.name
        
        ## gen unique job name
        #chars = string.ascii_uppercase + string.digits
            
        # backend call
        conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                certfile=settings.BASE_DIR+"/SSL/frontend.crt")
        job_id = conn.root.schedule(ldap_username(request), ldap_home(request), str(image), str(flags), str(partition), str(num_gpus), str(num_nodes), str(job_name), str(gpus_type))
     
        if int(job_id) > 0:
            SlurmJob.objects.create(name=job_name, image_name=name, num_gpus=num_gpus, num_nodes=num_nodes,
                                    user=request.user.username, slurm_id=int(job_id), frontend=settings.CARME_FRONTEND_ID, gpu_type=gpus_type)
            print("Queued job {} for user {} on {} nodes".format(job_id, ldap_username(request), num_nodes))
        else:
            print("ERROR queueing job {} for user {} on {} nodes".format(job_name, ldap_username(request), num_nodes))

            raise Exception("ERROR starting job")

        return HttpResponseRedirect('/')

    # if a GET (or any other method) we'll create a blank form
    else:
        messages.error(self.request,'This is not a POST method.') 
        #form = StartJobForm(image_choices=imageC, node_choices=nodeC, gpu_choices=gpuC, gpu_type_choices=gpuT)
    
    # render template
    #context = {
    #    'form': form
    #}

    return render(request, 'home.html', context)

@login_required(login_url='/account/login')
def job_hist(request):
    """renders the job history page"""
   
     #logout
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    # ldap
    group = list(request.user.ldap_user.group_names)[0]
    uID = request.user.ldap_user.attrs['uidNumber'][0]

    # history card (used ldap uID)
    myjobhist = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=uID).order_by('-time_end')[:20]
    myslurmid_list = list(myjobhist.values_list('id_job', flat=True))
    
    cases = [When(slurm_id=foo, then=sort_order) for sort_order, foo in enumerate(myslurmid_list)]
    myslurmjob = SlurmJob.objects.filter(slurm_id__in=myslurmid_list).annotate(
        sort_order=Case(*cases, output_field=IntegerField())).order_by('sort_order')
    
    mylist_long  = zip( list(myjobhist), list(myslurmjob) ) # last 20

    # compute total GPU hours (uses ldap uID)
    job_time_end = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=uID).aggregate(Sum('time_end'))['time_end__sum']
    job_time_start = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=uID).aggregate(Sum('time_start'))['time_start__sum']
    job_time = 0
    if (job_time_start and job_time_end):
        job_time = round((job_time_end-job_time_start)/3600)

    # render template
    context = {
        'myjobhist': myjobhist,
        'myslurmjob': myslurmjob,
        'mylist_long': mylist_long,
        'job_time': job_time,
    }

    return render(request, 'job_hist.html', context)

@login_required(login_url='/account/login')
def job_info(request):
    """ renders the job info page"""

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    empty_form = True

    if request.method == 'POST':
        # create a form instance and populate it with data from the request:
        form = JobInfoForm(request.POST)

        # check whether it's valid:
        if form.is_valid():
            job_details = SlurmJob.objects.filter(
                slurm_id__exact=form.cleaned_data['jobID'], status__exact="running")
            job_slurm = CarmeJobTable.objects.filter(
                id_job__exact=form.cleaned_data['jobID'])

            if len(job_slurm)>0:
                job_submit_time = datetime.fromtimestamp(
                        job_slurm[0].time_submit).strftime('%Y-%m-%d %H:%M:%S')
                job_start_time = datetime.fromtimestamp(
                        job_slurm[0].time_start).strftime('%Y-%m-%d %H:%M:%S')
                job_timelimit = datetime.fromtimestamp(min(
                    job_slurm[0].timelimit*60+job_slurm[0].time_start, 4099680000)).strftime('%Y-%m-%d %H:%M:%S')
                job_partition = job_slurm[0].partition
                job_cores = job_slurm[0].cpus_req
                job_mem = job_slurm[0].mem_req
                job_nodes = job_slurm[0].nodes_alloc
                # slurm compact format - need full list of IPs for graph_list
                job_node_list = job_slurm[0].nodelist

            graph_list = []
            gpu_list = []

            if len(job_details) > 0:
                for job in job_details:
                    gpu_list = job.gpu_ids.split(",")
                    for i in range(job.num_gpus):
                        GPU_usage_path = "zabbix-graphs/GPU_" + \
                            str(gpu_list[i])+'_use_'+str(job.ip)+'.png'
                        graph_list.append(GPU_usage_path)
                        GPU_mem_path = "zabbix-graphs/GPU_" + \
                            str(gpu_list[i])+'_mem_'+str(job.ip)+'.png'
                        graph_list.append(GPU_mem_path)
    
                context = {
                    'job_details': job_details,
                    'graph_list': graph_list,
                    'job_submit_time': job_submit_time,
                    'job_start_time': job_start_time,
                    'job_timelimit': job_timelimit,
                    'job_partition': job_partition,
                    'job_cores': job_cores,
                    'job_mem': job_mem,
                    'job_nodes': job_nodes,
                    'job_node_list': job_node_list,
                }

                empty_form = False
    
    if empty_form:
        form = JobInfoForm()

        context = {
            'form': form,
        }

    # render template
    return render(request, 'job_info.html', context)

#@force_maintenance_mode_off
#def custom_login(request):
#    if request.user.is_authenticated:
#        return redirect('/')
#    else:
#        return login(request)


#@force_maintenance_mode_off
#def login(request):
#    """custom login"""
#
#    return LoginView.as_view(template_name='login.html')(request)

##@force_maintenance_mode_off
##def login_page(request):
##    login_data = LoginForm()
##    return render(request, 'login.html', {'login_data':login_data})

##@force_maintenance_mode_off
##def login_validate(request):
##    login_data = LoginForm(request.POST)
##
##    if login_data.is_valid():
##        user = authenticate(username=request.POST['username'], password=request.POST['password'])
##        if user is not None:
##           # if user.is_active:
##            login(request, user)
##            return redirect('/')
##            #return LoginView.as_view(template_name='login.html')(request)
##
##        error_message= 'Incorrect password / username. Try again.'
##        return render(request, 'login.html', {'login_data':login_data,'login_errors':error_message})
##    error_message= 'Internal error. Please contact the admin.'
##    return render(request, 'login.html', {'login_data':login_data,'login_errors':error_message})
@force_maintenance_mode_off
def login(request):
    return redirect("two_factor:login")

@force_maintenance_mode_off
def logout(request):
    """custom logout"""

    path = '/account/login/'

    if request.user.is_authenticated:
        auth_logout(request)
        path += '?logout=1'
    
    return HttpResponseRedirect(path)

@login_required(login_url='/account/login')
def stop_job(request):
    """stopping a job (handing request to backend)"""

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    if request.method == 'POST':
        # create a form instance and populate it with data from the request:
        form = StopJobForm(request.POST)

        # check whether it's valid:
        if form.is_valid():
            jobID = form.cleaned_data['jobID']
            jobName = form.cleaned_data['jobName']
            jobUser = form.cleaned_data['jobUser']

            # backend call
            conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                    certfile=settings.BASE_DIR+"/SSL/frontend.crt")
            
            if conn.root.cancel(str(jobID), str(jobUser)) != 0:
                print("Error stopping job {} from user {}".format(jobID, jobUser))
                raise Exception("ERROR stopping job [backend]")

            return HttpResponseRedirect('/carme/JobTable/')
        else:
            return HttpResponse('<h3>Error - Invalid Form: {}</h3>'.format(form.cleaned_data['jobUser']))

    return HttpResponse('')  # HttpResponseRedirect('/')

@login_required(login_url='/account/login')
def change_password(request):
    """change password site (request handled by backend"""

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    if request.method == 'POST':
        form = ChangePasswd(request.POST)
        if form.is_valid():
            # init
            user_dn = request.user.ldap_user.dn
            pw1 = str(form.cleaned_data['new_password1'])
            pw2 = str(form.cleaned_data['new_password2'])
            
            # whether the password passed all checks
            valid_password = check_password(pw1, pw2)

            if valid_password:
                # backend call
                conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                        certfile=settings.BASE_DIR+"/SSL/frontend.crt")

                if conn.root.change_password(str(user_dn), ldap_username(request), pw1):
                    mess = "Password update for user: "+str(user_dn)
                    dj_messages.success(request, mess)
                else:
                    mess = "LDAP error for: "+str(user_dn)
                    dj_messages.error(request, mess)
                
                return redirect('change_password')
            else:
                dj_messages.error(
                    request, 'Passwords must match and must meet the requirements above!')
                
                return redirect('change_password')
        else:
            dj_messages.error(request, 'Please correct the error below.')
    else:
        form = ChangePasswd()
    
    # render template
    context = {
        'form': form,
        'password_criteria': password_criteria
    }

    return render(request, 'change_password.html', context)

@force_maintenance_mode_off
def messages(request):
    """generate list of user messages"""

    if not request.user.is_authenticated:
        return HttpResponse('Unauthorized', status=401)

    message_list = list(CarmeMessage.objects.filter(user__exact=request.user.username).order_by('-id'))[:10] # select only 10 latest messages
    message_list.reverse() # reverse message list for correct appendance on update
    
    # render template
    context = {
        'message_list': message_list,
    }

    return render(request, 'blocks/messages.html', context)

def proxy_auth(request):
    """authenticates connection requests (called py proxy)"""

    if request.user.is_authenticated:
        if "HTTP_X_FORWARDED_PREFIX" in request.META:
            path = request.META["HTTP_X_FORWARDED_PREFIX"] # in case of theia strip-prefix sets the prefix
        elif "HTTP_X_FORWARDED_URI" in request.META:
            path = request.META["HTTP_X_FORWARDED_URI"] # in normal cases the uri is used

        if request.user.is_superuser: # superusers can access every job
            return HttpResponse(status=200) # ok
        elif len(path) > 0:
            first = path[1:].split("/")[0] # [1:] removes / from beginning

            if first.startswith("nb_") or first.startswith("ta_") or first.startswith("tb_"):
                url_suffix = first[3:] # remove prefix part
                jobs = SlurmJob.objects.filter(url_suffix__exact=url_suffix, user__exact=request.user, status__exact="running")

                if(len(jobs) > 0):
                    return HttpResponse(status=200) # ok
    
    return HttpResponse(status=403) # forbidden


#def color(request):
#    if(request.POST.get('result_data')):
#        listt= request.POST['result_data']
#        listt= listt.split(",")
#        print('we have' + request.POST.get('result_data'))
#        request.session['colorful'] = listt[0]
#        request.session['chartborder'] = listt[1]
#        request.session['colormode'] = listt[2]
#    return JsonResponse({'success':True})

#####################################
#####################################
######## Starts HighCharts ##########
#####################################
#####################################

class LineChartJSONViewTime(HighchartPlotLineChartView):

    xAxispoints = 10 # static value chosen
    
    def get_providers(self):

        return ["Free", "Used", "Queued"]

    def get_labels(self):
    
        stat_gpus = np.asarray(ClusterStat.objects.values_list('date').order_by('-id'))
        
        dates = []
        dates.append(stat_gpus[0][0].strftime('%H:%M'))
        
        i,j = 1,1
        while i < self.xAxispoints:
            if stat_gpus[j][0].strftime('%Y-%m-%d,%H:%M') == stat_gpus[j-1][0].strftime('%Y-%m-%d,%H:%M'):
                pass
            else:
                dates.append(stat_gpus[j][0].strftime('%H:%M'))
                i+=1
            j+=1

        dates.reverse()
        dates[len(dates)-1] = '<b>Now</b>'
        
        return dates

    def get_data(self):

        stat_gpus = np.asarray(ClusterStat.objects.values_list('date','used','free','queued').order_by('-id'))
        
        used_gpus = []
        free_gpus = []
        queued_gpus = []
        used_gpus.append(stat_gpus[0][1])
        free_gpus.append(stat_gpus[0][2])
        queued_gpus.append(stat_gpus[0][3])
        
        i,j = 1,1
        while i < self.xAxispoints:
            if stat_gpus[j][0].strftime('%Y-%m-%d,%H:%M') == stat_gpus[j-1][0].strftime('%Y-%m-%d,%H:%M'):
                pass
            else:
                used_gpus.append(stat_gpus[j][1])
                free_gpus.append(stat_gpus[j][2])
                queued_gpus.append(stat_gpus[j][3])
                i+=1
            j+=1

        
        used_gpus.reverse()
        free_gpus.reverse()
        queued_gpus.reverse()

        return [
            free_gpus,
            used_gpus,
            queued_gpus
        ]

    def get_colors(self):

        color = [(45, 212, 191),(76, 157, 255),(0, 0, 0)]
        return next_color(color)
    
    def get_x_axis_options(self):
        return {
            "categories": self.get_labels(), 
            "title": {
                "text": "Time (CET)", 
                "margin": 15,
            }, 
            "min": 0.3,
            "max":self.xAxispoints-1.3,
            "plotLines": [{
                "width": "1",
                "value": "9", 
            }]
        }

    def get_markers(self):
        return [ {"symbol": 'circle', "radius":4.5},
                 {"symbol": 'square', "radius":3.9},
                 {"symbol": 'diamond', "radius":5}  ]

    title = _("")
    y_axis_title = _("GPUs")  


    credits = {
        "enabled": False,
        "text": "christian ortiz",
    }

class BaseForecast():
    xAxispoints = 8 #choose number of points
    
    acceleratorQuery = Accelerator.objects.filter()                                                                    
                                                                                                                   
    accelerator_name = list(acceleratorQuery.order_by('id').values_list('name',flat=True))                             
    accelerator_name = list({value:"" for value in accelerator_name}) # remove duplicates                                                 
                                                                                                                   
    accelerator_type = []                                                                                              
    accelerator_name_num_total = []                                                                                    
    accelerator_type_num_total = []                                                                                    
                                                                                                                   
    for num in range(len(accelerator_name)):                                                                           
                                                                                                                   
        # type                                                                                                         
        acceleratorNameQuery=Accelerator.objects.filter(name__exact=accelerator_name[num]) # e.g., all GTXs            
        accelerator_type_single = acceleratorNameQuery.order_by('id').values_list('type',flat=True).first()            
        accelerator_type.append(accelerator_type_single)                                                               
        # name_total                                                                                                   
        accelerator_name_num_per_node = list(acceleratorNameQuery.order_by('id').values_list('num_per_node',flat=True))
        accelerator_name_sum = sum(accelerator_name_num_per_node)                                                      
        accelerator_name_num_total.append(accelerator_name_sum)                                                        
        # type_total                                                                                                   
        acceleratorTypeQuery=Accelerator.objects.filter(type__exact=accelerator_type_single)                           
        accelerator_type_num_per_node = list(acceleratorTypeQuery.order_by('id').values_list('num_per_node',flat=True))
        accelerator_type_sum = sum(accelerator_type_num_per_node)                                                      
        accelerator_type_num_total.append(accelerator_type_sum)                                                        

    # setting variables gpu card
    #gputype=[]
    #gputotal=[]
        
    #for num in range(len(settings.CARME_GPU_NUM.split())):
    #    gputype.append(settings.CARME_GPU_NUM.split()[num].split(":")[0])
    #    accelerator_db = Accelerator.objects.filter(name__exact="TITAN")[0]
    #    nodestatus = accelerator_db.node_status                                                     
    #    if nodestatus == 0:
    #        gputotal.append("0")
    #    else:
    #        gputotal.append(settings.CARME_GPU_NUM.split()[num].split(":")[2])
        
    #gputotal = list(map(int, gputotal))

    #gpus=gputype # user sets the gpu_type list
    #numgpus = gputotal # user sets the total quantity of gpus available for each type   

    gpus = accelerator_name             
    numgpus = accelerator_name_num_total
    

    def get_providers(self):
        return ["Free", "Used", "Queued"]
    
    def get_colors(self):
        color = [(45, 212, 191),(76, 157, 255),(0, 0, 0)] #red:(230,55,87)
        return next_color(color)
    
    def get_x_axis_options(self):
        return {
            "categories": self.get_labels(), 
            "title": {
                "text": "Time (CET)", 
                "margin": 15,
            }, 
            "min": 0.3,
            "max":self.xAxispoints-1.3, 
            "plotLines": [{
                "width": "1",
                "value": "0.5", 
            }]        
        }

    def get_markers(self):
        return [ {"symbol": 'circle', "radius":4.5},
                 {"symbol": 'square', "radius":3.9},
                 {"symbol": 'diamond', "radius":5} ]
                 #{"symbol": 'triangle', "radius":4.5} ]
    
    title = _("") # Title shows None if removed
    y_axis_title = _("GPUs")  

    credits = {
        "enabled": False, # Credits show highcharts.com if removed
        "text": "Christian Ortiz",
    }

    def get_base_data(self):
       
        run_sortedfuture=[]
        queue_sortedfuture=[]
    

        acceleratorQuery = Accelerator.objects.filter()                                                                    
                                                                                                                   
        accelerator_name = list(acceleratorQuery.order_by('id').values_list('name',flat=True))                             
        accelerator_name = list({value:"" for value in accelerator_name}) # remove duplicates                                                 
                                                                                                                   
        accelerator_type = []                                                                                              
        accelerator_name_num_total = []                                                                                    
        accelerator_type_num_total = []                                                                                    
                                                                                                                   
        for num in range(len(accelerator_name)):                                                                           
                                                                                                                   
            # type                                                                                                         
            acceleratorNameQuery=Accelerator.objects.filter(name__exact=accelerator_name[num]) # e.g., all GTXs            
            accelerator_type_single = acceleratorNameQuery.order_by('id').values_list('type',flat=True).first()            
            accelerator_type.append(accelerator_type_single)                                                               
            # name_total                                                                                                   
            accelerator_name_num_per_node = list(acceleratorNameQuery.order_by('id').values_list('num_per_node',flat=True))
            accelerator_name_sum = sum(accelerator_name_num_per_node)                                                      
            accelerator_name_num_total.append(accelerator_name_sum)                                                        
            # type_total                                                                                                   
            acceleratorTypeQuery=Accelerator.objects.filter(type__exact=accelerator_type_single)                           
            accelerator_type_num_per_node = list(acceleratorTypeQuery.order_by('id').values_list('num_per_node',flat=True))
            accelerator_type_sum = sum(accelerator_type_num_per_node)                                                      
            accelerator_type_num_total.append(accelerator_type_sum)                                                        

        gpus = accelerator_name              
        numgpus = accelerator_name_num_total 

        for k in range(len(gpus)):####

            run_gpus = np.asarray(SlurmJob.objects.filter(
                status__exact='running', gpu_type__exact=gpus[k]).values_list('slurm_id','num_nodes','num_gpus','gpu_type').order_by('slurm_id') or [('0','0','0',gpus[k])]) #### ####
            run_gpus[:,2] = run_gpus[:,1].astype(int)*run_gpus[:,2].astype(int)
            run_gpus = np.delete(run_gpus, 1, 1)  # (slurm_id, num_gpus = num_gpus * num_nodes, gpu_type)  
            run_time = np.asarray(CarmeJobTable.objects.filter(
                id_job__in=run_gpus[:,0]).values_list('timelimit','time_start').order_by('id_job') or [(0,0)])
            run_future = np.c_[run_gpus[:,1],60*run_time[:,0]+run_time[:,1]] # (num_gpus in run, time_end)
            run_sortedfuture.append(np.array(sorted(run_future.astype(int),key=lambda x: x[1]))) # sorted by time_end 
                
            queue_gpus = np.asarray(SlurmJob.objects.filter(
                status__exact='queued', gpu_type__exact=gpus[k]).values_list('slurm_id','num_nodes','num_gpus','gpu_type').order_by('slurm_id') or [('0','0','0',gpus[k])]) ### ###
            queue_gpus[:,2] = queue_gpus[:,1].astype(int)*queue_gpus[:,2].astype(int)
            queue_gpus = np.delete(queue_gpus, 1, 1) # (slurm_id, num_gpus = num_spus * num_nodes, gpu_type) 
            queue_time = np.asarray(CarmeJobTable.objects.filter(
                id_job__in=queue_gpus[:,0]).values_list('timelimit','time_submit').order_by('id_job') or [(0,0)])
            queue_future = np.c_[queue_gpus[:,1],queue_time[:,1],queue_time[:,0]] # (num_gpus in queue, time_submit, timelimit)
            queue_sortedfuture.append(np.array(sorted(queue_future.astype(int),key=lambda x: x[1]))) # sorted by time_submit 
        
        # Initial state
        free_0 = []
        queue_0 = []
        used_0 = []
        for k in range(len(gpus)): ###
            free_0.append(numgpus[k] - sum(run_sortedfuture[k][:,0])) # free gpus  ###
            queue_0.append(sum(queue_sortedfuture[k][:,0])) # queue gpus
            used_0.append(numgpus[k] - free_0[k]) # used gpus ###

        forecast = [] 
        for k in range(len(gpus)): ###
            if queue_sortedfuture[k][0,1]==0: 
                forecast.append(np.zeros((len(run_sortedfuture[k]), 6)).astype(int))
            else:
                forecast.append(np.zeros((len(run_sortedfuture[k])+len(queue_sortedfuture[k]),6)).astype(int))

        # Calculation starts
        for k in range(len(gpus)): ###

            # time = 0: when first running job ends 
            run_sortedfuture[k][0,0] = free_0[k] + run_sortedfuture[k][0,0] # free gpus at t=0
            
            # time = 0: processing queued jobs
            for j in range(len(queue_sortedfuture[k])):
                if queue_sortedfuture[k][j,1] <= run_sortedfuture[k][0,1]: # time_submit <= time_end  
                    if queue_sortedfuture[k][j,0] <= run_sortedfuture[k][0,0]: # num_gpus_queued <= num_gpus_running
                        if queue_sortedfuture[k][j,0] != 0:
                            run_sortedfuture[k][0,0] = run_sortedfuture[k][0,0] - queue_sortedfuture[k][j,0] # free gpus at t=0
                            # jth-queued job listed in new_run as a new running job
                            new_run = np.array([[queue_sortedfuture[k][j,0],60*queue_sortedfuture[k][j,2] + run_sortedfuture[k][0,1]]])  
                            run_sortedfuture[k] = np.r_[run_sortedfuture[k],new_run]
                            run_sortedfuture[k] = np.array(sorted(run_sortedfuture[k],key=lambda x: x[1])) # jobs running including new_run
                            queue_sortedfuture[k][j,0] = 0

            # time = 0: after processing queued jobs
            forecast[k][0,0] = run_sortedfuture[k][0,0] # free gpus at t=0
            forecast[k][0,1] = sum(queue_sortedfuture[k][:,0]) # queue gpus at t=0
            forecast[k][0,2] = numgpus[k] - forecast[k][0,0] # used gpus at t=0 ###
            forecast[k][0,3] = forecast[k][0,0] - free_0[k] # free per time 
            forecast[k][0,4] = forecast[k][0,1] - queue_0[k] # queue per time 
            forecast[k][0,5] = forecast[k][0,2] - used_0[k] # used per time 

            # time > 0
            for i in range(1,len(forecast[k])):

                # time > 0: when next running job ends 
                run_sortedfuture[k][i,0] = run_sortedfuture[k][i-1,0] + run_sortedfuture[k][i,0] # free gpus at t_i

                # time > 0: processing queued jobs
                for j in range(len(queue_sortedfuture[k])):
                    if queue_sortedfuture[k][j,1] <= run_sortedfuture[k][i,1]:
                        if queue_sortedfuture[k][j,0] <= run_sortedfuture[k][i,0]:
                            if queue_sortedfuture[k][j,0] != 0:
                                run_sortedfuture[k][i,0] = run_sortedfuture[k][i,0] - queue_sortedfuture[k][j,0] # free gpus at t_i
                                # jth-queued job listed in new_run as a new running job
                                new_run = np.array([[queue_sortedfuture[k][j,0],60*queue_sortedfuture[k][j,2] + run_sortedfuture[k][i,1]]])  
                                run_sortedfuture[k] = np.r_[run_sortedfuture[k],new_run]
                                run_sortedfuture[k] = np.array(sorted(run_sortedfuture[k],key=lambda x: x[1])) # jobs running including new_run
                                queue_sortedfuture[k][j,0] = 0

                # time > 0: after processing queued jobs                
                forecast[k][i,0] = run_sortedfuture[k][i,0] # free gpus at t_i        
                forecast[k][i,1] = sum(queue_sortedfuture[k][:,0]) # queue gpus at t_i 
                forecast[k][i,2] = numgpus[k] - forecast[k][i,0] # used gpus at t_i  ###
                forecast[k][i,3] = forecast[k][i,0] - forecast[k][i-1,0] # free per time
                forecast[k][i,4] = forecast[k][i,1] - forecast[k][i-1,1] # queue per time
                forecast[k][i,5] = forecast[k][i,2] - forecast[k][i-1,2] # used per time
        ### 
        ### Compute Single Forecast (chart for each GPU) 
        forecast_single = [np.c_[forecast[k],run_sortedfuture[k][:,1],run_sortedfuture[k][:,1]] for k in range(len(gpus))] # add time_end (doubled) ###
        forecast_single = [forecast_single[k][:,[0,1,2,6,7]] for k in range(len(gpus))] # free / queue / used / time_end / time_end ###
        forecast_single = [np.array(sorted(forecast_single[k],key=lambda x: x[3])) for k in range(len(gpus)) ] # sort by time_end ## ####
        forecast_single = [forecast_single[k].astype(str) for k in range(len(gpus)) ] # convert to string    ###    
        
        for k in range(len(gpus)): # Express time in ECT datetime ###
            for count, x in enumerate(forecast_single[k][:,3]): 
                if (forecast_single[k][count,3]) != '0':
                    forecast_single[k][count,3]=datetime.fromtimestamp(int(x)).strftime('%H:%M<br/>%b-%d')
                    forecast_single[k][count,4]=datetime.fromtimestamp(int(x)).strftime('%H:%M,%b-%d-%y')
                else:
                    forecast_single[k][count,3]='none'
                    forecast_single[k][count,4]='none'
            for i in range(1,len(forecast_single[k])): # Remove duplicate times
                if forecast_single[k][i,3]==forecast_single[k][i-1,3]:
                    forecast_single[k][i-1,3]=0
            #if (any(forecast_single[k][:,3])=='0'):
            #    print(True)
            forecast_single[k] = np.delete(forecast_single[k], forecast_single[k][:,3]=='0', axis=0)

            if datetime.now().strftime('%H:%M<br/>%b-%d') == forecast_single[k][0,3]: # Add now() time with initial state data      
                forecast_single[k][0,3] = 'Now'
                forecast_single[k][0,4] = 'Now'
            else:
                forecast_single[k] = np.r_[[[free_0[k], queue_0[k], used_0[k], 'Now', datetime.now().strftime('%H:%M,%b-%d-%y')]], forecast_single[k]] 
            #if (any(forecast_single[k][:,3])=='none'):
            forecast_single[k] = np.delete(forecast_single[k], forecast_single[k][:,3]=='none', axis=0) 
            
        for k in range(len(gpus)): ###
            if len(forecast_single[k]) < 8:
                count = len(forecast_single[k])
                while count < 8:
                    if forecast_single[k][-1,3] == 'Now':
                        last_time_short=datetime.fromtimestamp(int(datetime.strptime(forecast_single[k][-1,4], '%H:%M,%b-%d-%y').timestamp())+3600).strftime('%H:%M<br/>%b-%d')
                        last_time_long=datetime.fromtimestamp(int(datetime.strptime(forecast_single[k][-1,4], '%H:%M,%b-%d-%y').timestamp())+3600).strftime('%H:%M,%b-%d-%y')
                        forecast_single[k] = np.r_[forecast_single[k],[[forecast_single[k][-1,0], forecast_single[k][-1,1], forecast_single[k][-1,2], last_time_short, last_time_long]]] 
                    else:
                        last_time_short=datetime.fromtimestamp(int(datetime.strptime(forecast_single[k][-1,4], '%H:%M,%b-%d-%y').timestamp())+3600).strftime('%H:%M<br/>%b-%d')
                        last_time_long=datetime.fromtimestamp(int(datetime.strptime(forecast_single[k][-1,4], '%H:%M,%b-%d-%y').timestamp())+3600).strftime('%H:%M,%b-%d-%y')
                        forecast_single[k] = np.r_[forecast_single[k],[[forecast_single[k][-1,0], forecast_single[k][-1,1], forecast_single[k][-1,2], last_time_short, last_time_long]]] 
                    count += 1



        ### Compute Total Forecast (chart for all GPUs) 
        forecast_total = np.concatenate([np.c_[forecast[k],run_sortedfuture[k][:,1],run_sortedfuture[k][:,1]] for k in range(len(gpus))]) # add time_end (doubled) ###
        forecast_total = np.array(sorted(forecast_total,key=lambda x: x[6])) # sort by time_end
        #if (any(forecast_total[:,6])==0):
        forecast_total = np.delete(forecast_total, forecast_total[:,6] == 0, axis=0) # delete empty rows 
        if forecast_total.size == 0:
            forecast_total = np.array([[sum(free_0), sum(queue_0), sum(used_0), 'Now', datetime.now().strftime('%H:%M,%b-%d-%y')]])
        else:
            forecast_total[0,3] = int(forecast_total[0,3]) + sum(free_0) # total free at t=0
            forecast_total[0,4] = int(forecast_total[0,4]) + sum(queue_0) # total queue at t=0
            forecast_total[0,5] = int(forecast_total[0,5]) + sum(used_0) # total used at t=0

            for i in range(1,len(forecast_total)):
                forecast_total[i,3] = int(forecast_total[i,3]) + int(forecast_total[i-1,3]) # total free at t_i
                forecast_total[i,4] = int(forecast_total[i,4]) + int(forecast_total[i-1,4]) # total queue at t_i
                forecast_total[i,5] = int(forecast_total[i,5]) + int(forecast_total[i-1,5]) # total used at t_i
            forecast_total = forecast_total[:,3:].astype(str)

            for count, x in enumerate(forecast_total[:,3]): # Express time in ECT datetime
                forecast_total[count,3]=datetime.fromtimestamp(int(x)).strftime('%H:%M<br/>%b-%d')
                forecast_total[count,4]=datetime.fromtimestamp(int(x)).strftime('%H:%M,%b-%d-%y')
            for i in range(1,len(forecast_total)): # Remove duplicate times
                if forecast_total[i,3]==forecast_total[i-1,3]:
                    forecast_total[i-1,3]=0
            #if (any(forecast_total[:,3])=='0'):
            forecast_total = np.delete(forecast_total, forecast_total[:,3]=='0', axis=0)
            if datetime.now().strftime('%H:%M<br/>%b-%d') == forecast_total[0,3]: # Add now() time with initial state data        
                forecast_total[0,3] = '<b>Now</b>'
            else:
                forecast_total = np.r_[[[sum(free_0), sum(queue_0), sum(used_0), '<b>Now</b>', datetime.now().strftime('%H:%M,%b-%d-%y')]], forecast_total]    

        if len(forecast_total) < 8:
            count = len(forecast_total)
            while count < 8:
                if forecast_total[-1,3] == '<b>Now</b>':
                    last_time_short=datetime.fromtimestamp(int(datetime.strptime(forecast_total[-1,4], '%H:%M,%b-%d-%y').timestamp())+3600).strftime('%H:%M<br/>%b-%d')
                    last_time_long=datetime.fromtimestamp(int(datetime.strptime(forecast_total[-1,4], '%H:%M,%b-%d-%y').timestamp())+3600).strftime('%H:%M,%b-%d-%y')
                    forecast_total = np.r_[forecast_total,[[forecast_total[-1,0], forecast_total[-1,1], forecast_total[-1,2], last_time_short, last_time_long]]] 
                else:
                    last_time_short=datetime.fromtimestamp(int(datetime.strptime(forecast_total[-1,4], '%H:%M,%b-%d-%y').timestamp())+3600).strftime('%H:%M<br/>%b-%d')
                    last_time_long=datetime.fromtimestamp(int(datetime.strptime(forecast_total[-1,4], '%H:%M,%b-%d-%y').timestamp())+3600).strftime('%H:%M,%b-%d-%y')
                    forecast_total = np.r_[forecast_total,[[forecast_total[-1,0], forecast_total[-1,1], forecast_total[-1,2], last_time_short, last_time_long]]] 
                count += 1


        cast = forecast_single
        cast.insert(0, forecast_total) # all forecasts

        return cast

class LineChartJSONViewForecast(BaseForecast,HighchartPlotLineChartView):

    def get_labels(self):
        dates = list(BaseForecast().get_base_data()[self.k][:self.xAxispoints,3]) 
        return dates

    def get_data(self): 
        
        free = list(map(int,BaseForecast().get_base_data()[self.k][:self.xAxispoints,0])) 
        queued = list(map(int,BaseForecast().get_base_data()[self.k][:self.xAxispoints,1]))
        used = list(map(int,BaseForecast().get_base_data()[self.k][:self.xAxispoints,2]))  
        
        return [free,used,queued]

line_chart_json_time = LineChartJSONViewTime.as_view()

if (len(BaseForecast().accelerator_name)) == 0:
    print('Accelerators are not available')
elif (len(BaseForecast().accelerator_name)) == 1:
    for i in range(len(BaseForecast().accelerator_name)):
            def init_forecast(self,i=i): # equivalent to def __init__(self,i) in Class
                self.k = i
                self.xAxispoints = BaseForecast().xAxispoints
                super(LineChartJSONViewForecast, self)

            exec("LineChartJSONViewForecast"+str(i)+"=type('LineChartJSONViewForecast"+str(i)+"',(LineChartJSONViewForecast,),{'__init__': init_forecast})")
            exec('line_chart_json_forecast' + str(i) + ' = ' + 'LineChartJSONViewForecast' + str(i)+ '.as_view()')
else:
    for i in range(len(BaseForecast().accelerator_name)+1):
        def init_forecast(self,i=i): # equivalent to def __init__(self,i) in Class
            self.k = i
            self.xAxispoints = BaseForecast().xAxispoints
            super(LineChartJSONViewForecast, self)

        exec("LineChartJSONViewForecast"+str(i)+"=type('LineChartJSONViewForecast"+str(i)+"',(LineChartJSONViewForecast,),{'__init__': init_forecast})")
        exec('line_chart_json_forecast' + str(i) + ' = ' + 'LineChartJSONViewForecast' + str(i)+ '.as_view()')
