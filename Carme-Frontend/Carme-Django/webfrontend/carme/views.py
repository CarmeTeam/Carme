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

import numpy as np
from django.http import HttpResponse
from django.template import loader
from .models import CarmeMessage, SlurmJob, Image, CarmeJobTable, ClusterStat, GroupResource
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

# Charts
from django.utils.translation import gettext_lazy as _
from .highchart.colors import COLORS, next_color
from .highchart.lines import HighchartPlotLineChartView

# History Card
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

def ldap_username(request):
    return request.user.ldap_user.attrs['uid'][0]

def ldap_home(request):
    return request.user.ldap_user.attrs['homeDirectory'][0]

# no view, should be a model
def generateChoices(request):
    """generates the list of items for the image drop down menu"""

    group = list(request.user.ldap_user.group_names)[0]
    group_resources = GroupResource.objects.filter(name__exact=group)[0]

    # generate image choices
    image_list = Image.objects.filter(group__exact=group, status__exact="active")
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


@login_required(login_url='/login') 
def index(request):
    """ dashboard page -> generates user job-list, messages and other interactive features"""

    # logout
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    # ldap
    group = list(request.user.ldap_user.group_names)[0]
    uID = request.user.ldap_user.attrs['uidNumber'][0]
    
    # jobs history (uses ldap uID)
    myjobhist = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=uID).order_by('-time_end')[:20]
    
    myslurmid_list = list(myjobhist.values_list('id_job', flat=True))
    
    cases = [When(slurm_id=foo, then=sort_order) for sort_order, foo in enumerate(myslurmid_list)]
    myslurmjob = SlurmJob.objects.filter(slurm_id__in=myslurmid_list).annotate(
        sort_order=Case(*cases, output_field=IntegerField())).order_by('sort_order')
    
    mylist_short = zip( list(myjobhist[:4]), list(myslurmjob[:4]) ) # last 4
    mylist_long  = zip( list(myjobhist), list(myslurmjob) ) # last 20

    # compute total GPU hours in jobs history  (uses ldap uID)
    job_time_end = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=uID).aggregate(Sum('time_end'))['time_end__sum']
    job_time_start = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=uID).aggregate(Sum('time_start'))['time_start__sum']
    job_time = 0
    if (job_time_start and job_time_end):
        job_time = round((job_time_end-job_time_start)/3600)

    # create start job form
    nodeC, gpuC, imageC, gpuT = generateChoices(request)
    startForm = StartJobForm(image_choices=imageC,
                             node_choices=nodeC, gpu_choices=gpuC, gpu_type_choices=gpuT)

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
    
    # setting variables gpu card
    gputype=[]
    cpupergpu=[]
    rampergpu=[]
    gpupernode=[]
    gputotal=[]
    for num in range(len(settings.CARME_GPU_DEFAULTS.split())):
        gputype.append(settings.CARME_GPU_DEFAULTS.split()[num].split(":")[0])
        cpupergpu.append(settings.CARME_GPU_DEFAULTS.split()[num].split(":")[1])
        rampergpu.append(settings.CARME_GPU_DEFAULTS.split()[num].split(":")[2])
        
    for num in range(len(settings.CARME_GPU_NUM.split())):
        gpupernode.append(settings.CARME_GPU_NUM.split()[num].split(":")[1])
        gputotal.append(settings.CARME_GPU_NUM.split()[num].split(":")[2])
        
    cpupergpu = list(map(int, cpupergpu))
    rampergpu = list(map(int, rampergpu))
    gpupernode = list(map(int, gpupernode))
    gputotal = list(map(int, gputotal))
    gpusum = sum(gputotal)
    
    # loop gpu type chart
    gpu_loop = range(len(gputype)+1)
    
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

    stats["free"] = gpusum - (stats["used"] + stats["reserved"])

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
        'start_job_form': startForm,
        'CARME_VERSION': settings.CARME_VERSION,
        'DEBUG': settings.DEBUG,
        'mylist_short': mylist_short,
        'mylist_long': mylist_long,
        'job_time' : job_time,
        'gpu_loop' : gpu_loop,
        'gputype': gputype, #gpucard
        'cpupergpu': cpupergpu, #gpucard
        'rampergpu': rampergpu, #gpucard
        'gpupernode':gpupernode, #gpucard
        'gputotal':gputotal, #gpucard
        'gpusum': gpusum, #gpucard
    }

    return render(request, 'home.html', context)


@login_required(login_url='/login')
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

@login_required(login_url='/login')
def start_job(request):
    """starts a new job (handing request to backend)"""

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    group = list(request.user.ldap_user.group_names)[0]
    partition = GroupResource.objects.filter(name__exact=group)[0].partition

    nodeC, gpuC, imageC, gpuT = generateChoices(request)

    # if this is a POST request we need to process the form data
    if request.method == 'POST':
        # create a form instance and populate it with data from the request:
        form = StartJobForm(
            request.POST, image_choices=imageC, node_choices=nodeC, gpu_choices=gpuC, gpu_type_choices=gpuT)
        
        # check whether it's valid:
        if form.is_valid():
            # get image path and mounts from choices
            image_db = Image.objects.filter(group__exact=group,
                                                   name__exact=form.cleaned_data['image'])[0]
            flags = image_db.flags
            image = image_db.path
            name = image_db.name

            # add job to db
            num_nodes = int(form.cleaned_data['nodes'])
            num_gpus = int(form.cleaned_data['gpus'])
            job_name = str(form.cleaned_data['name'])[:32]

            # gen unique job name
            chars = string.ascii_uppercase + string.digits
            gpus_type = str(form.cleaned_data['gpu_type'])

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
        form = StartJobForm(image_choices=imageC,
                            node_choices=nodeC, gpu_choices=gpuC, gpu_type_choices=gpuT)
    
    # render template
    context = {
        'form': form
    }

    return render(request, 'jobs.html', context)

@login_required(login_url='/login')
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

@login_required(login_url='/login')
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

@force_maintenance_mode_off
def custom_login(request):
    if request.user.is_authenticated:
        return redirect('/')
    else:
        return login(request)


@force_maintenance_mode_off
def login(request):
    """custom login"""

    return LoginView.as_view(template_name='login.html')(request)

#@force_maintenance_mode_off
#def login_page(request):
#    login_data = LoginForm()
#    return render(request, 'login.html', {'login_data':login_data})

#@force_maintenance_mode_off
#def login_validate(request):
#    login_data = LoginForm(request.POST)
#
#    if login_data.is_valid():
#        user = authenticate(username=request.POST['username'], password=request.POST['password'])
#        if user is not None:
#           # if user.is_active:
#            login(request, user)
#            return redirect('/')
#            #return LoginView.as_view(template_name='login.html')(request)
#
#        error_message= 'Incorrect password / username. Try again.'
#        return render(request, 'login.html', {'login_data':login_data,'login_errors':error_message})
#    error_message= 'Internal error. Please contact the admin.'
#    return render(request, 'login.html', {'login_data':login_data,'login_errors':error_message})

@force_maintenance_mode_off
def logout(request):
    """custom logout"""

    path = '/login/'

    if request.user.is_authenticated:
        auth_logout(request)
        path += '?logout=1'
    
    return HttpResponseRedirect(path)

@login_required(login_url='/login')
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

@login_required(login_url='/login')
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
        return {"categories": self.get_labels(), "title": {"text": "Time (CET)", "margin": 15}, "min": 0.3,"max":self.xAxispoints-1.3,
        "plotLines": [{
        "color": "#aeb1b5",
        "width": "1",
        "value": "9",
        "dashStyle": "Dash" 
        }]
        }

    def get_markers(self):
        return [{"symbol": 'circle', "radius":4.5},{"symbol": 'square', "radius":3.9},{"symbol": 'diamond', "radius":5}]

    title = _("")
    y_axis_title = _("GPUs")  


    credits = {
        "enabled": False,
        "text": "christian ortiz",
    }

class BaseForecast():
    xAxispoints = 8 #choose number of points
    
    # setting variables gpu card
    gputype=[]
    gputotal=[]
        
    for num in range(len(settings.CARME_GPU_NUM.split())):
        gputype.append(settings.CARME_GPU_NUM.split()[num].split(":")[0])
        gputotal.append(settings.CARME_GPU_NUM.split()[num].split(":")[2])
        
    gputotal = list(map(int, gputotal))

    gpus=gputype # user sets the gpu_type list
    numgpus = gputotal # user sets the total quantity of gpus available for each type   

    def get_providers(self):
        return ["Free", "Used", "Queued" ]
    
    def get_colors(self):
        color = [(45, 212, 191),(76, 157, 255),(0, 0, 0)]
        return next_color(color)
    
    def get_x_axis_options(self):
        return {"categories": self.get_labels(), "title": {"text": "Time (CET)", "margin": 15}, "min": 0.3,"max":self.xAxispoints-1.3,
        "plotLines": [{
        "color": "#aeb1b5",
        "width": "1",
        "value": "0.5",
        "dashStyle": "Dash" 
        }]        
        }

    def get_markers(self):
        return [{"symbol": 'circle', "radius":4.5},{"symbol": 'square', "radius":3.9},{"symbol": 'diamond', "radius":5}]
    
    title = _("") # Title shows None if removed
    y_axis_title = _("GPUs")  

    credits = {
        "enabled": False, # Credits show highcharts.com if removed
        "text": "Christian Ortiz",
    }

    def get_base_data(self):
       
        run_sortedfuture=[]
        queue_sortedfuture=[]

        for k in range(len(self.gpus)):

            run_gpus = np.asarray(SlurmJob.objects.filter(
                status__exact='running', gpu_type__exact=self.gpus[k]).values_list('slurm_id','num_nodes','num_gpus','gpu_type').order_by('slurm_id') or [('0','0','0',self.gpus[k])])
            run_gpus[:,2] = run_gpus[:,1].astype(int)*run_gpus[:,2].astype(int)
            run_gpus = np.delete(run_gpus, 1, 1)  # (slurm_id, num_gpus = num_gpus * num_nodes, gpu_type)  
            run_time = np.asarray(CarmeJobTable.objects.filter(
                id_job__in=run_gpus[:,0]).values_list('timelimit','time_start').order_by('id_job') or [(0,0)])
            run_future = np.c_[run_gpus[:,1],60*run_time[:,0]+run_time[:,1]] # (num_gpus in run, time_end)
            run_sortedfuture.append(np.array(sorted(run_future.astype(int),key=lambda x: x[1]))) # sorted by time_end 
                
            queue_gpus = np.asarray(SlurmJob.objects.filter(
                status__exact='queued', gpu_type__exact=self.gpus[k]).values_list('slurm_id','num_nodes','num_gpus','gpu_type').order_by('slurm_id') or [('0','0','0',self.gpus[k])])
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
        for k in range(len(self.gpus)):
            free_0.append(self.numgpus[k] - sum(run_sortedfuture[k][:,0])) # free gpus
            queue_0.append(sum(queue_sortedfuture[k][:,0])) # queue gpus
            used_0.append(self.numgpus[k] - free_0[k]) # used gpus

        forecast = [] 
        for k in range(len(self.gpus)):
            if queue_sortedfuture[k][0,1]==0: 
                forecast.append(np.zeros((len(run_sortedfuture[k]), 6)).astype(int))
            else:
                forecast.append(np.zeros((len(run_sortedfuture[k])+len(queue_sortedfuture[k]),6)).astype(int))

        # Calculation starts
        for k in range(len(self.gpus)):

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
            forecast[k][0,2] = self.numgpus[k] - forecast[k][0,0] # used gpus at t=0
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
                forecast[k][i,2] = self.numgpus[k] - forecast[k][i,0] # used gpus at t_i 
                forecast[k][i,3] = forecast[k][i,0] - forecast[k][i-1,0] # free per time
                forecast[k][i,4] = forecast[k][i,1] - forecast[k][i-1,1] # queue per time
                forecast[k][i,5] = forecast[k][i,2] - forecast[k][i-1,2] # used per time
        
        ### Compute Single Forecast (chart for each GPU) 
        forecast_single = [np.c_[forecast[k],run_sortedfuture[k][:,1],run_sortedfuture[k][:,1]] for k in range(len(self.gpus))] # add time_end (doubled)
        forecast_single = [forecast_single[k][:,[0,1,2,6,7]] for k in range(len(self.gpus))] # free / queue / used / time_end / time_end
        forecast_single = [np.array(sorted(forecast_single[k],key=lambda x: x[3])) for k in range(len(self.gpus)) ] # sort by time_end
        forecast_single = [forecast_single[k].astype(str) for k in range(len(self.gpus)) ] # convert to string
        
        
        for k in range(len(self.gpus)): # Express time in ECT datetime
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
            forecast_single[k] = np.delete(forecast_single[k], forecast_single[k][:,3]=='0', axis=0)

            if datetime.now().strftime('%H:%M<br/>%b-%d') == forecast_single[k][0,3]: # Add now() time with initial state data      
                forecast_single[k][0,3] = 'Now'
                forecast_single[k][0,4] = 'Now'
            else:
                forecast_single[k] = np.r_[[[free_0[k], queue_0[k], used_0[k], 'Now', datetime.now().strftime('%H:%M,%b-%d-%y')]], forecast_single[k]] 
            forecast_single[k] = np.delete(forecast_single[k], forecast_single[k][:,3]=='none', axis=0) 
        
        for k in range(len(self.gpus)):
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
        forecast_total = np.concatenate([np.c_[forecast[k],run_sortedfuture[k][:,1],run_sortedfuture[k][:,1]] for k in range(len(self.gpus))]) # add time_end (doubled)
        forecast_total = np.array(sorted(forecast_total,key=lambda x: x[6])) # sort by time_end
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

if (len(BaseForecast().gpus)) == 0:
    print('GPU_TYPE is empty')
elif (len(BaseForecast().gpus)) == 1:
    for i in range(len(BaseForecast().gpus)):
            def init_forecast(self,i=i): # equivalent to def __init__(self,i) in Class
                self.k = i
                self.xAxispoints = BaseForecast().xAxispoints
                super(LineChartJSONViewForecast, self)

            exec("LineChartJSONViewForecast"+str(i)+"=type('LineChartJSONViewForecast"+str(i)+"',(LineChartJSONViewForecast,),{'__init__': init_forecast})")
            exec('line_chart_json_forecast' + str(i) + ' = ' + 'LineChartJSONViewForecast' + str(i)+ '.as_view()')
else:
    for i in range(len(BaseForecast().gpus)+1):
        def init_forecast(self,i=i): # equivalent to def __init__(self,i) in Class
            self.k = i
            self.xAxispoints = BaseForecast().xAxispoints
            super(LineChartJSONViewForecast, self)

        exec("LineChartJSONViewForecast"+str(i)+"=type('LineChartJSONViewForecast"+str(i)+"',(LineChartJSONViewForecast,),{'__init__': init_forecast})")
        exec('line_chart_json_forecast' + str(i) + ' = ' + 'LineChartJSONViewForecast' + str(i)+ '.as_view()')


