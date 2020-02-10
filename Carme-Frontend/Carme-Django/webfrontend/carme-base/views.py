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
from .models import CarmeMessages, SlurmJobs, Images, CarmeJobTable, CarmeAssocTable, ClusterStat, GroupResources
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
import datetime
import rpyc
from django.db.models import Sum
import logging  # django logging module
from random import randint
from django.views.generic import TemplateView
from chartjs.views.lines import BaseLineChartView
import re


def calculate_jobheight(numjobs):
    return 200 + numjobs * 60

def page_not_found(request):
    return render(request,'404.html', status=404) 

def error(request):
    return render(request,'500.html', status=500)

@login_required(login_url='/login') 
def index(request):
    """ rendering of the website / -> template:home.html

    #Details: generates user job-list, messages and other interactive fearutes

    """
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    current_user = request.user.username
    slurm_list_user = SlurmJobs.objects.filter(user__exact=current_user)
    slurm_list = SlurmJobs.objects.exclude(status__exact="timeout") #do not show rime out jobs in admin job-table
    numjobs = len(slurm_list_user)
    jobheight = calculate_jobheight(numjobs) + numjobs * 10
    message_list = list(CarmeMessages.objects.filter(user__exact=current_user).order_by('-id'))[:10] #select only 10 latest messages
    template = loader.get_template('../templates/home.html')
    nodeC, gpuC, imageC, gpuT = generateChoices(request)
    startForm = StartJobForm(image_choices=imageC,
                             node_choices=nodeC, gpu_choices=gpuC, gpu_type_choices=gpuT)

    #update Cluster stats
    StatUsedGPUs=0
    StatQueudGPUs=0
    for j in slurm_list:
        if j.status == "running":
            StatUsedGPUs += j.NumGPUs * j.NumNodes
        elif j.status == "queued":
            StatQueudGPUs += j.NumGPUs * j.NumNodes 

    if (str(StatQueudGPUs)=="None"):
        StatQueudGPUs=0
    if (str(StatUsedGPUs)=="None"):
        StatUsedGPUs=0
    StatReservedGPUs = 0 #NOTE not implemented yet
    StatFreeGPUs = settings.CARME_HARDWARE_NUM_GPUS - (StatUsedGPUs + StatReservedGPUs)
    timestamp = datetime.datetime.now()
    #check if stats have changed
    lastStat=ClusterStat.objects.latest('id')
    if (lastStat.free!=StatFreeGPUs or lastStat.queued != StatQueudGPUs):
        ClusterStat.objects.create(date=timestamp, free=StatFreeGPUs, used=StatUsedGPUs, reserved=StatReservedGPUs, queued=StatQueudGPUs) 

    context = {
        'slurm_list_user': slurm_list_user,
        'slurm_list': slurm_list,
        'message_list': message_list,
        'start_job_form': startForm,
        'numjobs': numjobs,
        'jobheight': jobheight,
        'CARME_VERSION': settings.CARME_VERSION,
        'DEBUG': settings.DEBUG,
    }
    return HttpResponse(template.render(context, request))

@login_required(login_url='/login')
def admin_job_table(request):
    """ renders the admin job table

    """
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    current_user = request.user.username
    slurm_list = SlurmJobs.objects.exclude(status__exact="timeout")
    numjobs = len(slurm_list)
    jobheight = calculate_jobheight(numjobs)
    template = loader.get_template('../templates/admin_job_table.html')

    context = {
        'slurm_list': slurm_list,
        'numjobs': numjobs,
        'jobheight': jobheight,
    }
    return HttpResponse(template.render(context, request))

@login_required(login_url='/login')
def admin_cluster_status(request):
    """ renders the admin cluster status

    """
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    current_user = request.user.username
    slurm_list = SlurmJobs.objects.all()
    numjobs = len(slurm_list)
    jobheight = calculate_jobheight(numjobs)
    template = loader.get_template('../templates/admin_cluster_status.html')

    context = {
        'slurm_list': slurm_list,
        'numjobs': numjobs,
        'jobheight': jobheight,
    }

    return HttpResponse(template.render(context, request))

@login_required(login_url='/login')
def image_table(request):
    """ renders the images site

    """
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    current_user = request.user.username
    template = loader.get_template('../templates/imagetable.html')
    image_list_active = Images.objects.filter(image_status__exact="active")
    image_list_sandbox = Images.objects.filter(image_status__exact="sandbox")
    context = {
        'image_list_active': image_list_active,
        'image_list_sandbox': image_list_sandbox,
    }
    return HttpResponse(template.render(context, request))


@login_required(login_url='/TimeOut')
def job_table(request):
    """ renders the user job table and add new slurm jobs after starting

    """
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
    template = loader.get_template('../templates/jobtable.html')
    context = {
        'slurm_list_user': slurm_list_user,
        'numjobs': numjobs,
        'jobheight': jobheight,
    }
    return HttpResponse(template.render(context, request))


# computes user dependend choices for start_job
def generateChoices(request):
    """ generates the list of items for the image drop down menue

    """
    if not request.user.is_authenticated:
        return HttpResponseRedirect('/login')
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    group = list(request.user.ldap_user.group_names)[0]
    # .order_by('image_name')  # ,image_status__exact="active")
    image_list = Images.objects.filter(image_group__exact=group, image_status__exact="active")
    image_choices = set()
    for i in image_list:
        image_choices.add((i.image_name, i.image_name))

    group_resources = GroupResources.objects.filter(group_name__exact=group)[0]
   
    node_choices =[]
    for i in range(1, group_resources.group_max_nodes +1):
        node_choices.append( (str(i), i) )
        
    gpu_choices = []
    for i in range(1, group_resources.group_max_gpus_per_node +1):
        gpu_choices.append( (str(i), i) )

    gpu_type = [(str(i), i) for i in settings.CARME_GPU_TYPE.split(',')]

    return node_choices, gpu_choices, sorted(list(image_choices)), gpu_type

@login_required(login_url='/login')
def start_job(request):
    """ starts a new job (handing request to backend)

    """
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    # setup logger
    db_logger = logging.getLogger('db')

    group = list(request.user.ldap_user.group_names)[0]
    group_resources = GroupResources.objects.filter(group_name__exact=group)[0]
    partition = group_resources.group_partition
    print (partition)
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
            # sanbox images have special queue
            if (image_db.image_status == "sandbox"):
                partition = settings.CARME_SANDBOX_PARTITION
                mounts = settings.CARME_SANDBOX_MOUNT
            # add job to db
            num_nodes = int(form.cleaned_data['nodes'])
            num_gpus = int(form.cleaned_data['gpus'])
            user_name = str(form.cleaned_data['name']).replace(" ", "")[:32]
            # gen unique job name
            chars = string.ascii_uppercase + string.digits
            #remove non alpha numerics 
            jobname = re.sub(r'[^a-zA-Z0-9_]', '',user_name)#''.join(e for e in user_name if e.isalnum())
            jobname = jobname + '_' + \
                ''.join(random.choice(chars) for _ in range(4))
            #if num_nodes > 1:  # current hack to make multi-node jobs axclusive
            #    num_gpus = 2
            gpus_type = str(form.cleaned_data['gpu-type'])

            m = SlurmJobs.objects.create(jobName=jobname, imageName=name, NumGPUs=num_gpus, NumNodes=num_nodes,
                                         user=request.user.username, SLURM_ID=(0-random.randint(1, 10000)), frontend=settings.CARME_FRONTEND_ID, gpu_type=gpus_type)

            # backend call
            conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                    certfile=settings.BASE_DIR+"/SSL/frontend.crt")
            if conn.root.StartJob(str(request.user.username), str(m.id), str(image), str(mounts), str(partition), str(num_gpus), str(num_nodes), str(jobname), str(gpus_type)) != 0:
                message = "FRONTEND: ERROR queing job " + \
                    str(jobname) + " for user " + str(request.user.username) + \
                    " on " + str(num_nodes) + " nodes"
                db_logger.exception(message)
                raise Exception("ERROR starting job")
            else:
                message = "FRONTEND: queued job " + str(jobname) + " for user " + str(
                    request.user.username) + " on " + str(num_nodes) + " nodes"
                db_logger.info(message)
            return HttpResponseRedirect('/')

    # if a GET (or any other method) we'll create a blank form
    else:
        form = StartJobForm(image_choices=imageC,
                            node_choices=nodeC, gpu_choices=gpuC, gpu_type_choices=gpuT)
    return render(request, 'jobs.html', {'form': form})

@login_required(login_url='/login')
def job_hist(request):
    """ renders the job history page

    """
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    current_user = request.user.username
    group = list(request.user.ldap_user.group_names)[0]
    uID = request.user.ldap_user.attrs['uidNumber'][0]
    template = loader.get_template('../templates/job_hist.html')
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
    assoc = CarmeAssocTable.objects.filter(user__exact=current_user)
    partitions = ""
    #for a in assoc:
    #    partitions += str(a.partition)+" "

    group_resources = GroupResources.objects.filter(group_name__exact=group)[0]

    context = {
        'myjobhist': myjobhist,
        'uID': uID,
        'job_time': job_time,
        'partitions': group_resources.group_partition,
        'max_jobs': group_resources.group_max_jobs,
        'max_nodes': group_resources.group_max_nodes,
        'max_gpus': group_resources.group_max_gpus_per_node,
    }
    return HttpResponse(template.render(context, request))

@login_required(login_url='/login')
def job_info(request):
    """ renders the job info page

    """
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    if request.method == 'POST':
        form = JobInfoForm(request.POST)
        # check whether it's valid:

        if form.is_valid():
            template = loader.get_template(
                '../templates/job_info.html')
            job_details = SlurmJobs.objects.filter(
                SLURM_ID__exact=form.cleaned_data['jobID'], status__exact="running")
            job_slurm = CarmeJobTable.objects.filter(
                id_job__exact=form.cleaned_data['jobID'] )
            if len(job_slurm)>0:
                job_submit_time = datetime.datetime.fromtimestamp(
                        job_slurm[0].time_submit).strftime('%Y-%m-%d %H:%M:%S')
                job_start_time = datetime.datetime.fromtimestamp(
                        job_slurm[0].time_start).strftime('%Y-%m-%d %H:%M:%S')
                job_timelimit = datetime.datetime.fromtimestamp(min(
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
                gpu_list = job_details[0].GPUS.split(",")
                for job in job_details:
                    for i in range(job.NumGPUs):
                        GPU_usage_path = "zabbix-graphs/GPU_" + \
                            str(gpu_list[i])+'_use_'+str(job.IP)+'.png'
                        graph_list.append(GPU_usage_path)
                        GPU_mem_path = "zabbix-graphs/GPU_" + \
                            str(gpu_list[i])+'_mem_'+str(job.IP)+'.png'
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
            return HttpResponse(template.render(context, request))
    # if a GET (or any other method) we'll create a blank form

    else:
        form = JobInfoForm()
    return render(request, 'job_info.html', {'form': form})

@login_required(login_url='/login')
def stop_job(request):
    """ stopping a job (handing request to backend)

    """
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    # setup logger
    db_logger = logging.getLogger('db')

    if request.method == 'POST':
        # create a form instance and populate it with data from the request:
        form = StopJobForm(request.POST)
        # check whether it's valid:
        if form.is_valid():
            jobID = form.cleaned_data['jobID']
            jobName = form.cleaned_data['jobName']
            jobUser = form.cleaned_data['jobUser']

            # delete job from db -> moved to backend
            #try:
            #    m = SlurmJobs.objects.filter(SLURM_ID=int(jobID)).delete()
            #    print ("delete query: ", jobID, jobName, jobUser)
            #    print (m[0])
            #    while m[0]!=0:
            #        m = SlurmJobs.objects.filter(SLURM_ID=int(jobID)).delete()
            #        print ("delete query: ", jobID, jobName, jobUser)
            #        print (m[0])
            #except:
            #    raise Exception("ERROR stopping job [DB]")

            # backend call
            conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                    certfile=settings.BASE_DIR+"/SSL/frontend.crt")
            if conn.root.StopJob(str(jobID), str(jobName), str(jobUser)) != 0:
                message = "FRONTEND: Error stopping job " + \
                    str(jobName) + " for user " + str(jobUser)
                db_logger.exception(message)
                raise Exception("ERROR stopping job [backend]")

            #message = "FRONTEND: stoped job " + \
            #    str(jobName) + " for user " + str(jobUser)
            #db_logger.info(message)
            # HttpResponse('<h3>'+str(mess)+'</h3>')
            return HttpResponseRedirect('/carme-base/JobTable/')
        else:
            return HttpResponse('<h3>Error - Invalid Form: '+str(form.cleaned_data['jobUser'])+'</h3>')

    return HttpResponse('')  # HttpResponseRedirect('/')

@login_required(login_url='/login')
def change_password(request):
    """ change password site (request handled by backend"

    """
    request.session.set_expiry(settings.SESSION_AUTO_LOGOUT_TIME)

    if request.method == 'POST':
        form = ChangePasswd(request.POST)
        if form.is_valid():
            # update ldap
            user_dn = request.user.ldap_user.dn
            # check new pw
            password = str(form.cleaned_data['new_password1'])
            length_error = len(password) < 13  # length
            digit_error = re.search(r"\d", password) is None  # digits
            uppercase_error = re.search(r"[A-Z]", password) is None  # case
            symbol_error = re.search(
                r"[ !#$%&'()*+,-./[\\\]^_`{|}~"+r'"]', password) is None  # symbols
            equal_error = str(form.cleaned_data['new_password1']) != str(
                form.cleaned_data['new_password2'])
            password_ok = not (
                length_error or digit_error or uppercase_error or symbol_error or equal_error)

            if (password_ok):
                # backend call
                conn = rpyc.ssl_connect(settings.CARME_BACKEND_SERVER, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                        certfile=settings.BASE_DIR+"/SSL/frontend.crt")
                password = str(form.cleaned_data['new_password2'])
                if conn.root.SetPassword(str(user_dn), str(request.user.username), password):
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
    return render(request, '../templates/change_password.html', {'form': form})

def messages(request):
    """ generate list of user messages 

    """
    current_user = request.user.username
    message_list = list(CarmeMessages.objects.filter(user__exact=current_user).order_by('-id'))[:10] #select only 10 latest messages
    template = loader.get_template('../templates/blocks/messages.html')  
    context = {
            'message_list': message_list,

            }
    return HttpResponse(template.render(context, request))    

def time_out(request):
    """ rendering time out 

    """
    template = loader.get_template('../templates/time_out.html')
    context = {}
    return HttpResponse(template.render(context, request))


def auth(request):
    """ authenticates connection requests (called py proxy)

    """
    if not request.user.is_authenticated:
        print("not loged in")
        return redirect('login')  # HttpResponseForbidden()

    else:
        print("login OK")
        return HttpResponse(status=200)

class LineChartJSONView(BaseLineChartView):
    """ data backend for chartjs cluster stats

    """
    def get_labels(self):
        """ provide chart lables


        """
        now = datetime.datetime.now()
        StatGPUs = np.asarray(ClusterStat.objects.values_list('date').order_by('id'))

        rawdates = StatGPUs[-16:] 
        dates = list(map(lambda x: str(x[0].hour )+":"+str(x[0].minute).zfill(2), rawdates))
        lables=[]
        for i in range(np.shape(StatGPUs[-16:,0])[0]-1):
            lables.append("t"+str(i-np.shape(StatGPUs[-16:,0])[0]+1))
        lables.append("now")

        return dates

    def get_providers(self):
        """ provide data set names

        """
        return ["reserved","used", "queued", "free"]

    def get_data(self):
        """ provides actual data

        """
        StatGPUs = np.asarray(ClusterStat.objects.values_list('used','free','queued','reserved').order_by('id'))
        StatUsedGPUs = list(StatGPUs[-16:,0]) 
        StatFreeGPUs = list(StatGPUs[-16:,1]) 
        StatQueuedGPUs = list(StatGPUs[-16:,2]) 
        StatReservedGPUs = list(StatGPUs[-16:,3])

        return [StatReservedGPUs,
                StatUsedGPUs,
                StatQueuedGPUs,
                StatFreeGPUs
                ]
        
    def get_datasets(self):
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

