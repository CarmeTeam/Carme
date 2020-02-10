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
from .models import CarmeMessages, SlurmJobs, Images, CarmeJobTable, ClusterStat, GroupResources
from django.shortcuts import render
from django.http import HttpResponseRedirect, HttpResponseForbidden
from .forms import MessageForm, DeleteMessageForm, StartJobForm, StopJobForm, ChangePasswd, JobInfoForm
from django.contrib import messages as dj_messages
from django.contrib.auth import update_session_auth_hash
from django.contrib.auth.forms import PasswordChangeForm
from django.contrib.auth.decorators import login_required
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
from chartjs.views.lines import BaseLineChartView
import re

def ldap_username(request):
    return request.user.ldap_user.attrs['uid'][0]

def ldap_home(request):
    return request.user.ldap_user.attrs['homeDirectory'][0]

def calculate_jobheight(numjobs):
    """calculate the approximate job table height"""

    return 200 + numjobs * 60

# no view, should be a model
def generateChoices(request):
    """generates the list of items for the image drop down menue"""

    group = list(request.user.ldap_user.group_names)[0]
    group_resources = GroupResources.objects.filter(group_name__exact=group)[0]

    # generate image choices
    image_list = Images.objects.filter(image_group__exact=group, image_status__exact="active")
    image_choices = set()
    for i in image_list:
        image_choices.add((i.image_name, i.image_name))

    # generate num_nodes choices
    node_choices =[]
    for i in range(1, group_resources.group_max_nodes +1):
        node_choices.append( (str(i), i) )

    # generate num_gpus choices
    gpu_choices = []
    for i in range(1, group_resources.group_max_gpus_per_node +1):
        gpu_choices.append( (str(i), i) )

    # generate gpu_type choices
    gpu_type = [(str(i), i) for i in settings.CARME_GPU_TYPE.split(',')]

    return node_choices, gpu_choices, sorted(list(image_choices)), gpu_type

@login_required(login_url='/login') 
def index(request):
    """rendering of the website / -> template:home.html

    #Details: generates user job-list, messages and other interactive fearutes
    """

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    # create start job form
    nodeC, gpuC, imageC, gpuT = generateChoices(request)
    startForm = StartJobForm(image_choices=imageC,
                             node_choices=nodeC, gpu_choices=gpuC, gpu_type_choices=gpuT)

    # calculate actual stats
    slurm_list = SlurmJobs.objects.exclude(status__exact="timeout")
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

    stats["free"] = settings.CARME_HARDWARE_NUM_GPUS - (stats["used"] + stats["reserved"])

    # check if stats have to be updated
    try:
        lastStat = ClusterStat.objects.latest('id')
    except:
        lastStat = None
    
    if (lastStat is None or lastStat.free != stats["free"] or lastStat.queued != stats["queued"]):
        ClusterStat.objects.create(date=datetime.now(), free=stats["free"], used=stats["used"], reserved=stats["reserved"], queued=stats["queued"]) 

    # render template
    context = {
        'start_job_form': startForm,
        'CARME_VERSION': settings.CARME_VERSION,
        'DEBUG': settings.DEBUG,
    }

    return render(request, 'home.html', context)

@login_required(login_url='/TimeOut')
def admin_job_table(request):
    """renders the admin job table"""

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    # get all jobs
    slurm_list = SlurmJobs.objects.all()
    numjobs = len(slurm_list)
    jobheight = calculate_jobheight(numjobs)

    # render template
    context = {
        'slurm_list': slurm_list,
        'numjobs': numjobs,
        'jobheight': jobheight,
    }

    return render(request, 'admin_job_table.html', context)

@login_required(login_url='/TimeOut')
def job_table(request):
    """renders the user job table and add new slurm jobs after starting"""

    # NOTE: no update of session ex time here!

    # setup logger
    db_logger = logging.getLogger('db')

    current_user = request.user.username
    # search for ready slurm jobs
    slurm_ready = SlurmJobs.objects.filter(status__exact="ready", user__exact=current_user, frontend__exact=settings.CARME_FRONTEND_ID)
    for job in slurm_ready:
        job.status = "configuring"  # set status to avoid deadlock loop on faield jobs
        job.save()
        conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                certfile=settings.BASE_DIR+"/SSL/frontend.crt")
        testtrigger = conn.root.SetTrigger(
            str(job.SLURM_ID), str(job.user), str(job.jobName))

        if testtrigger != 0:
            # delete job that can not be started from db - backen has notified used and admin
            #mess = 'Sarting job '+str(job.SLURM_ID)+' failed !'
            #messages.success(request, mess)  # add messages
            message = 'FRONTEND ERROR: Sarting job ' + \
                str(job.SLURM_ID)+' failed !'
            db_logger.exception(message)
            # set status to fialed -> keep job in db for later investigation an d debugging
            job.status = "failed"
            job.save()
        else:
            job.status = "running"  # job will now be displayed
            job.save()

            message = "FRONTEND: set trigger vals " + \
                str(job.SLURM_ID) + " " + \
                str(job.user) + " " + str(job.jobName)
            db_logger.info(message)

            # dirty theia port hack
            TA_PORT = job.TB_PORT + 1000

            # write route to proxy
            pfile = str(settings.CARME_PROXY_PATH) + \
                '/routes/dynamic/'+str(settings.CARME_FRONTEND_ID)+"-"+str(job.SLURM_ID)+".toml"
            f = open(pfile, 'w')
            route = '''
            [frontends.nb_'''+str(job.HASH)+''']
            backend = "nb_'''+str(job.HASH)+'''"
            passHostHeader = true
            [frontends.nb_'''+str(job.HASH)+'''.routes.route_1]
            rule = "Host:'''+str(settings.CARME_URL)+''';PathPrefix:/nb_'''+str(job.HASH)+'''"

            [backends.nb_'''+str(job.HASH)+''']
            [backends.nb_'''+str(job.HASH)+'''.servers.server1]
            url = "http://'''+str(job.IP)+''':'''+str(job.NB_PORT)+'''"

            [frontends.tb_'''+str(job.HASH)+''']
            backend = "tb_'''+str(job.HASH)+'''"
            entrypoints = ["https"]
            [frontends.tb_'''+str(job.HASH)+'''.routes.route_1]
            rule = "Host:'''+str(settings.CARME_URL)+''';PathPrefix:/tb_'''+str(job.HASH)+'''"

            [backends.tb_'''+str(job.HASH)+''']
            [backends.tb_'''+str(job.HASH)+'''.servers.server1]
            url = "http://'''+str(job.IP)+''':'''+str(job.TB_PORT)+'''"

            [frontends.dd_'''+str(job.HASH)+''']
            backend = "dd_'''+str(job.HASH)+'''"
            entrypoints = ["https"]
            [frontends.dd_'''+str(job.HASH)+'''.routes.route_1]
            rule = "Host:'''+str(settings.CARME_URL)+''';PathPrefix:/dd_'''+str(job.HASH)+'''"
            
            [backends.dd_'''+str(job.HASH)+''']
            [backends.dd_'''+str(job.HASH)+'''.servers.server1]
            url = "http://'''+str(job.IP)+''':8787"   

            [frontends.ta_'''+str(job.HASH)+'''] 
            backend = "ta_'''+str(job.HASH)+'''"
            entrypoints = ["https"]
            [frontends.ta_'''+str(job.HASH)+'''.routes.route_1]
            rule = "Host:'''+str(settings.CARME_URL)+''';PathPrefixStrip:/ta_'''+str(job.HASH)+'''"
            
            [backends.ta_'''+str(job.HASH)+''']
            [backends.ta_'''+str(job.HASH)+'''.servers.server1] 
            url = "http://'''+str(job.IP)+''':'''+str(TA_PORT)+'''"
            '''
            f.write(route)
            f.close()
            # stupid hack to trigger an inotifywait event and cause traefik to update config
            com = 'chmod 777 '+str(settings.CARME_PROXY_PATH)+'/routes/dynamic/*; rm '+str(
                settings.CARME_PROXY_PATH)+'/routes/dummy.toml;touch '+str(settings.CARME_PROXY_PATH)+'/routes/dummy.toml'
            if os.system(com) != 0:
                message = 'FRONTEND ERROR: Sarting job ' + \
                    str(job.SLURM_ID)+'('+str(settings.CARME_FRONTEND_ID)+') failed !'
                db_logger.exception(message)
                raise Exception("ERROR trafik job update")
    
    #check for timeout 
    slurm_running = SlurmJobs.objects.filter(status__exact="running", user__exact=current_user, frontend__exact=settings.CARME_FRONTEND_ID)
    for job in slurm_running:
        job_slurm = CarmeJobTable.objects.filter(
                id_job__exact=job.SLURM_ID )
        now = int(datetime.datetime.now().timestamp())
        if (job.status == "running") and (len(job_slurm) >0) and (job_slurm[0].timelimit>0):
            job_timelimit = job_slurm[0].timelimit*60+job_slurm[0].time_start
            if now > job_timelimit:
                print ("TIMEOUT :", str(job.SLURM_ID), " : ", job.status, " : ",job_timelimit, " ", now)
                job.status = "timeout"
                conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                    certfile=settings.BASE_DIR+"/SSL/frontend.crt")
                message = conn.root.SendNotify("Timeout " + str(job.jobName), str(job.user), "#00B5FF")
                job.save()





    slurm_list_user = SlurmJobs.objects.filter(user__exact=current_user)
    numjobs = len(slurm_list_user)
    jobheight = calculate_jobheight(numjobs)

    # render template
    context = {
        'slurm_list_user': slurm_list_user,
        'numjobs': numjobs,
        'jobheight': jobheight,
    }
    
    return render(request, 'jobtable.html', context)

@login_required(login_url='/login')
def start_job(request):
    """starts a new job (handing request to backend)"""

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    group = list(request.user.ldap_user.group_names)[0]
    partition = GroupResources.objects.filter(group_name__exact=group)[0].group_partition

    nodeC, gpuC, imageC, gpuT = generateChoices(request)

    # if this is a POST request we need to process the form data
    if request.method == 'POST':
        # create a form instance and populate it with data from the request:
        form = StartJobForm(
            request.POST, image_choices=imageC, node_choices=nodeC, gpu_choices=gpuC, gpu_type_choices=gpuT)
        
        # check whether it's valid:
        if form.is_valid():
            # get image path and mounts from choices
            image_db = Images.objects.filter(image_group__exact=group,
                                                   image_name__exact=form.cleaned_data['image'])[0]
            mounts = settings.CARME_BASE_MOUNTS  # set in carme settings
            mounts += str(image_db.image_mounts)
            image = image_db.image_path
            name = image_db.image_name

            # add job to db
            num_nodes = int(form.cleaned_data['nodes'])
            num_gpus = int(form.cleaned_data['gpus'])
            job_name = str(form.cleaned_data['name'])[:32]

            # gen unique job name
            chars = string.ascii_uppercase + string.digits
            gpus_type = str(form.cleaned_data['gpu-type'])

            # backend call
            conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                    certfile=settings.BASE_DIR+"/SSL/frontend.crt")
            job_id = conn.root.schedule(ldap_username(request), ldap_home(request), str(image), str(mounts), str(partition), str(num_gpus), str(num_nodes), str(job_name), str(gpus_type))
            
            if int(job_id) > 0:
                SlurmJobs.objects.create(name=job_name, image_name=name, num_gpus=num_gpus, num_nodes=num_nodes,
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

    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    group = list(request.user.ldap_user.group_names)[0]
    uID = request.user.ldap_user.attrs['uidNumber'][0]

    myjobhist = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=uID).order_by('-time_end')[:20]

    # compute total GPU hours
    uID = request.user.ldap_user.attrs['uidNumber'][0]
    job_time_end = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=uID).aggregate(Sum('time_end'))['time_end__sum']
    job_time_start = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=uID).aggregate(Sum('time_start'))['time_start__sum']
    job_time = 0
    if (job_time_start and job_time_end):
        job_time = round((job_time_end-job_time_start)/3600)

    group_resources = GroupResources.objects.filter(group_name__exact=group)[0]

    # render template
    context = {
        'myjobhist': myjobhist,
        'uID': uID,
        'job_time': job_time,
        'partitions': group_resources.group_partition,
        'max_jobs': group_resources.group_max_jobs,
        'max_nodes': group_resources.group_max_nodes,
        'max_gpus': group_resources.group_max_gpus_per_node,
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
            job_details = SlurmJobs.objects.filter(
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
            if conn.root.StopJob(str(jobID), str(jobName), str(jobUser)) != 0:
                message = "FRONTEND: Error stopping job " + \
                    str(jobName) + " for user " + str(jobUser)
                db_logger.exception(message)
                raise Exception("ERROR stopping job [backend]")

            return HttpResponseRedirect('/carme-base/JobTable/')
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
            password = str(form.cleaned_data['new_password1'])
            
            # check results
            valid_length = len(password) >= 13  # length
            valid_equality = str(form.cleaned_data['new_password1']) == str(
                form.cleaned_data['new_password2']) # equality

            char_types = []
            char_types.append(re.search(r"[0-9]", password) is not None)  # digits
            char_types.append(re.search(r"[A-Z]", password) is not None)  # uppercase
            char_types.append(re.search(r"[a-z]", password) is not None)  # lowercase
            char_types.append(re.search(r"[^0-9a-zA-Z]", password) is not None) # other

            valid_chars = sum(char_types) >= 3 # character types
            
            # whether the password passed all checks
            valid_password = valid_length and valid_equality and valid_chars

            if valid_password:
                # backend call
                conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                        certfile=settings.BASE_DIR+"/SSL/frontend.crt")
                password = str(form.cleaned_data['new_password2'])

                if conn.root.change_password(str(user_dn), ldap_username(request), password):
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
        'form': form
    }

    return render(request, 'change_password.html', context)

def messages(request):
    """generate list of user messages"""

    message_list = list(CarmeMessages.objects.filter(user__exact=request.user.username).order_by('-id'))[:10] #select only 10 latest messages
    
    # render template
    context = {
        'message_list': message_list,
    }

    return render(request, 'blocks/messages.html', context)

def time_out(request):
    """rendering time out"""
    
    # render template
    context = {}

    return render(request, 'time_out.html', context)


def auth(request):
    """authenticates connection requests (called py proxy)"""

    if not request.user.is_authenticated:
        return redirect('login')
    else:
        return HttpResponse(status=200)

def proxy_auth(request):
    """authenticates connection requests (called py proxy)"""

    if request.user.is_authenticated:
        if "HTTP_X_FORWARDED_PREFIX" in request.META:
            path = request.META["HTTP_X_FORWARDED_PREFIX"] # in case of theia strip-prefix sets the prefix
        elif "HTTP_X_FORWARDED_URI" in request.META:
            path = request.META["HTTP_X_FORWARDED_URI"] # in normal cases the uri is used

        if len(path) > 0:
            first = path[1:].split("/")[0] # [1:] removes / from beginning

            if first.startswith("nb_") or first.startswith("ta_") or first.startswith("tb_"):
                url_suffix = first[3:] # remove prefix part
                jobs = SlurmJobs.objects.filter(url_suffix__exact=url_suffix, user__exact=request.user)

                if(len(jobs) > 0):
                    return HttpResponse(status=200) # ok
    
    return HttpResponse(status=403) # forbidden

class LineChartJSONView(BaseLineChartView):
    """data backend for chartjs cluster stats"""

    def get_labels(self):
        """provide chart labels"""
        now = datetime.now()
        stat_gpus = np.asarray(ClusterStat.objects.values_list('date').order_by('id'))

        rawdates = stat_gpus[-16:] 
        dates = list(map(lambda x: str(x[0].hour )+":"+str(x[0].minute).zfill(2), rawdates))
        lables=[]

        for i in range(np.shape(stat_gpus[-16:,0])[0]-1):
            lables.append("t"+str(i-np.shape(stat_gpus[-16:,0])[0]+1))
        
        lables.append("now")

        return dates

    def get_providers(self):
        """provide data set names"""

        return ["reserved","used", "queued", "free"]

    def get_data(self):
        """provides actual data"""

        stat_gpus = np.asarray(ClusterStat.objects.values_list('used','free','queued','reserved').order_by('id'))
        used_gpus = list(stat_gpus[-16:,0]) 
        free_gpus = list(stat_gpus[-16:,1]) 
        queued_gpus = list(stat_gpus[-16:,2]) 
        reserved_gpus = list(stat_gpus[-16:,3])

        return [
            reserved_gpus,
            used_gpus,
            queued_gpus,
            free_gpus
        ]
        
    def get_datasets(self):
        """return datasets configuration"""

        datasets = super(LineChartJSONView, self).get_datasets()

        for dataset in datasets:
            if dataset["name"]=="free":
                dataset["backgroundColor"]="rgba(62, 249, 61, 0.5)"
                dataset["borderColor"]="rgba(62, 249, 61, 1.0)"
                dataset["pointBackgroundColor"]="rgba(62, 249, 61, 1.0)"
                dataset["pointBorderColor"]="rgba(0, 125, 0, 1.0)"
            elif dataset["name"]=="used":
                dataset["backgroundColor"]="rgba(106, 38, 189, 0.5)"
                dataset["borderColor"]="rgba(106, 38, 189, 1.0)"
                dataset["pointBackgroundColor"]="rgba(106, 38, 189, 1.0)"
                dataset["pointBorderColor"]="rgba(255, 255, 255, 1.0)"
            elif dataset["name"]=="queued":
                dataset["backgroundColor"]="rgba(135, 140, 135, 0.5)"
                dataset["borderColor"]="rgba(135, 140, 135, 1.0)"
                dataset["pointBackgroundColor"]="rgba(135, 140, 135, 1.0)"
                dataset["pointBorderColor"]="rgba(255, 255, 255, 1.0)"
            elif dataset["name"]=="reserved":
                dataset["backgroundColor"]="rgba(0, 181, 255, 0.5)"
                dataset["borderColor"]="rgba(0, 181, 255, 1.0)"
                dataset["pointBackgroundColor"]="rgba(0, 181, 255, 1.0)"
                dataset["pointBorderColor"]="rgba(255, 255, 255, 1.0)"
        
        return datasets

line_chart = TemplateView.as_view(template_name='line_chart.html')
line_chart_json = LineChartJSONView.as_view()
