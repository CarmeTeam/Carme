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
import os
import rpyc
import misaka
import requests
import numpy as np
from datetime import datetime

from django.db import connections # slurm
from carme.forms import StopJobForm, JobInfoForm
from carme.models import NewsMessage, CarmeMessage, SlurmJob, CarmeJobTable, ClusterStat
from projects.models import ProjectMember, ProjectHasTemplate, TemplateHasAccelerator, Accelerator, TemplateHasImage, ResourceTemplate, Image
from django.contrib.auth.models import User 
from django.contrib.auth.decorators import login_required

from django.http import HttpResponse, HttpResponseRedirect, JsonResponse
from django.shortcuts import render, redirect
from django.conf import settings
from django.contrib import messages as dj_messages

# Chart card
from django.core.serializers import serialize
from django.core.serializers.json import DjangoJSONEncoder
from django.utils.translation import gettext_lazy as _
from .highcharts.colors import COLORS, next_color
from .highcharts.lines import HighchartPlotLineChartView

# History card
from django.db.models import Sum, Case, Value, When, IntegerField 

from two_factor.views.core import LoginView

#try:
#    from django.utils.http import url_has_allowed_host_and_scheme
#except ImportError:
#    from django.utils.http import (
#        is_safe_url as url_has_allowed_host_and_scheme,
#    )

#-------------------------------#
#----- classes and methods -----#
#-------------------------------#

def my_info(request):
    """ user data """
    my_username = settings.CARME_USER
    my_group = settings.CARME_GROUP
    my_home = settings.CARME_HOME
    my_uid = settings.CARME_UID
    my_id = list(User.objects.filter(username__exact=settings.CARME_USER).order_by('id').values_list('id',flat=True))[0]

    """
    if settings.CARME_USERS == "single":
        my_username = settings.CARME_USER
        my_group = settings.CARME_GROUP
        my_home = settings.CARME_HOME
        my_uid = settings.CARME_UID
        my_id = list(User.objects.filter(username__exact=settings.CARME_USER).order_by('id').values_list('id',flat=True))[0]

    elif settings.CARME_USERS == "multi":
        my_username = request.user.ldap_user.attrs['uid'][0]
        my_group = request.user.ldap_user.attrs['group'][0] #to verify
        my_home = request.user.ldap_user.attrs['homeDirectory'][0]
        my_uid = request.user.ldap_user.attrs['uid'][0] #to verify
        my_id = request.user
    """

    return my_username, my_group, my_home, my_uid, my_id


def csrf_failure(request, reason=""):
    return redirect("/")             

# Login
class myLogin(LoginView):
    #redirect to the next page
    def dispatch(self, request, *args, **kwargs):
        if request.user.is_authenticated:
            return HttpResponseRedirect('/')
        else:
            return super(LoginView, self).dispatch(request, *args, **kwargs)

myLogin = myLogin.as_view()

@login_required(login_url='/account/login')
def index(request):
    """ dashboard page : news, system, chart, and jobs cards """
    
    my_username, my_group, my_home, my_uid, my_id = my_info(request)

    # news card ----------------------------------------------------------------------------------
    # curls github repository
    carme_message_response = requests.get("https://www.open-carme.org/message.md")
    if carme_message_response.status_code == 200:
        carme_message=os.popen("curl https://www.open-carme.org/message.md").read()
    else: 
        carme_message = "**Welcome to Carme**\n\nIf you have any questions, contact us:\n\ncarme@itwm.fraunhofer.de" 
    news_message = NewsMessage.objects.filter()
    if news_message.exists():
    	news_message.update(carme_message=carme_message)
    	if news_message.values_list('show_custom_message', flat=True)[0] == 1:
    		news=misaka.html(news_message.values_list('custom_message', flat=True)[0])
    	else:
    		news=misaka.html(news_message.values_list('carme_message', flat=True)[0])
    else:
        NewsMessage.objects.create(carme_message=carme_message)
        news=misaka.html(NewsMessage.objects.filter().values_list('carme_message', flat=True)[0])

    # system card --------------------------------------------------------------------------------
    # uses slurm.conf -> Accelerator model
    acceleratorQuery = Accelerator.objects.filter()
    
    accelerator_name = list(acceleratorQuery.order_by('id').values_list('name',flat=True))
    accelerator_name = list({value:"" for value in accelerator_name}) # remove duplicates 

    # top panel-----------------------
    accelerator_type = []
    accelerator_ratio = []
    accelerator_name_num_total = []
    accelerator_type_num_total = []
    # --------------------------------

    # bottom panel -------------------
    accelerator_node = []
    accelerator_node_status = []
    accelerator_num_per_node = []
    accelerator_num_cpus_per_node = []
    accelerator_main_mem_per_node = []
    # --------------------------------

    for num in range(len(accelerator_name)):

        # top panel -------------------------------------------------------------------------------

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
        # ------------------------------------------------------------------------------------------

        # bottom panel -----------------------------------------------------------------------------

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
        # ------------------------------------------------------------------------------------------

    # zipping
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

    # chart card ----------------------------------------------------------------------------------
    # uses Accelerator model

    # jobs card -----------------------------------------------------------------------------------
    # uses ProjectMember, ProjectHasTemplate, TemplateHasAccelerator, TemplateHasImage models
    
    # project and template | card header -----------------
    projectQueryActive = ProjectMember.objects.filter(user=my_id, 
                                                      is_approved_by_admin=True,
                                                      is_approved_by_manager=True,
                                                      status='accepted',
                                                      project__is_approved=True)
    project_id = list(projectQueryActive.order_by('id').values_list('project_id',flat=True))
    project_id = list(set(project_id))

    templateQuerySet = ProjectHasTemplate.objects.filter(project_id__in=project_id)
    project_name = list(templateQuerySet.order_by('id').values_list('project__name',flat=True))
    template_name = list(templateQuerySet.order_by('id').values_list('template__name',flat=True))
    
    # zipping
    project_and_template = zip(project_name, template_name)

    # slurm fields | card body ---------------------------
    accelerator_per_node_field = []
    accelerator_name_field = []
    accelerator_type_field = []
    image_field = []
    node_field = []
    for num in range(len(template_name)):

        #-----------------------------------------------------
        # filter by template_name TemplateHasAccelerator
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
        #--------------------------------------------------------
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
        #--------------------------------------------------------
        # image field
        resourceTemplateHasImageQuery = TemplateHasImage.objects.filter(resourcetemplate__name=template_name[num])
        image_name_single = resourceTemplateHasImageQuery.order_by('id').values_list('image__name',flat=True)
        image_field.append(image_name_single)


    jobs_field = zip(accelerator_name_field,accelerator_type_field,accelerator_per_node_field,node_field,image_field,template_name)
    jobs_field_js = zip(accelerator_name_field,accelerator_per_node_field,node_field)
    accs_field_js = zip(accelerator_name_field,accelerator_type_field)


    # jobs card -> jobs table ----------------------------------------------------------------------------
    slurm_list_user = SlurmJob.objects.filter(user__exact=request.user.username, status__in=["queued", "running"])
    myslurmid_active_list = list(slurm_list_user.values_list('slurm_id', flat=True))
    cases_active = [When(id_job=foo, then=sort_order) for sort_order, foo in enumerate(myslurmid_active_list)]
    jobtable_active = CarmeJobTable.objects.filter(id_job__in=myslurmid_active_list).annotate(
    sort_order=Case(*cases_active, output_field=IntegerField())).order_by('sort_order')
    myjobtable_list  = zip( list(slurm_list_user), list(jobtable_active) )
    myjobtable_script = zip ( list(slurm_list_user), list(jobtable_active) )

    # notifications in nav bar ---------------------------------------------------------------------------
    message_list = list(CarmeMessage.objects.filter(user__exact=request.user.username).order_by('-id'))[:10] #select only 10 latest messages
    
    # calculate actual stats
    #slurm_list = SlurmJob.objects.exclude(status__exact="timeout")
    #stats = {
    #    "used": 0,
    #    "queued": 0,
    #    "reserved": 0,
    #    "free": 0
    #}
    # 
    #for j in slurm_list:
    #    if j.status == "running":
    #        stats["used"] += j.num_gpus * j.num_nodes
    #    elif j.status == "queued":
    #        stats["queued"] += j.num_gpus * j.num_nodes 
    #
    #stats["free"] = accelerator_type_num_total[0] - (stats["used"] + stats["reserved"]) 

    # check if stats have to be updated
    #try:
    #    lastStat = ClusterStat.objects.latest('id')
    #except:
    #    lastStat = None
    # 
    #if (lastStat is None or lastStat.free != stats["free"] or lastStat.queued != stats["queued"]):
    #    ClusterStat.objects.create(date=datetime.now(), free=stats["free"], used=stats["used"], reserved=stats["reserved"], queued=stats["queued"])
    
    # render template
    context = {
        'myjobtable_list': myjobtable_list,
        'myjobtable_script': myjobtable_script,
        'message_list': message_list,
        # config ----------------------------------------------------
        'CARME_VERSION': settings.CARME_VERSION,
        'CARME_USERS':settings.CARME_USERS,
        # user info -------------------------------------------------
        'CARME_USER': my_username,
        'CARME_GROUP': my_group,
        # news card -------------------------------------------------
        'news': news,
        # system & chart cards --------------------------------------
        'accelerator_info': accelerator_info,
        'accelerator_name': accelerator_name,
        # jobs card -------------------------------------------------
        'project_and_template': project_and_template,
        'accs_field_js': accs_field_js,
        'jobs_field_js': jobs_field_js,
        'jobs_field': jobs_field,
    }

    return render(request, 'home.html', context)


def job_table(request):
    """renders the user job table and add new slurm jobs after starting"""

    my_username, my_group, my_home, my_uid, my_id = my_info(request)

    # jobs card
    slurm_list_user = SlurmJob.objects.filter(user__exact=my_username, status__in=["queued", "running"])
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


def start_job(request):
    """starts a new job (handing request to backend). Uses ResourceTemplate and Image"""

    my_username, my_group, my_home, my_uid, my_id = my_info(request)

    if request.method == 'POST':

        if not str(request.POST['name']):
            return redirect('/')

        nod_num = int(request.POST['nodes'])
        acc_num = int(request.POST['accelerators_pernode'])
        acc_name = str(request.POST['accelerator']).lower()
        job_name = str(request.POST['name'])[:32]
        tmp_name = str(request.POST['template'])

        partition = ResourceTemplate.objects.filter(name__exact=tmp_name)[0].partition
        userimage = Image.objects.filter(name__exact=str(request.POST['image']))[0]
        img_bind = userimage.bind
        img_path = userimage.path
        img_name = userimage.name

        # backend call
        conn = rpyc.ssl_connect(settings.CARME_BACKEND_NODE, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",certfile=settings.BASE_DIR+"/SSL/frontend.crt")
        job_id = conn.root.schedule(my_username, my_home, str(img_path), str(img_bind), str(partition), str(acc_num), str(nod_num), str(job_name), str(acc_name))
     
        if int(job_id) > 0:
            SlurmJob.objects.create(name=job_name, image_name=img_name, num_gpus=acc_num, num_nodes=nod_num,
                                    user=my_username, slurm_id=int(job_id), frontend=settings.CARME_FRONTEND_ID, gpu_type=acc_name)
            #print("Queued job {} for user {} on {} nodes".format(job_id, my_username, nod_num))
        else:
            print("ERROR queueing job {} for user {} on {} nodes".format(job_name, my_username, nod_num))
            raise Exception("ERROR starting job")

        return HttpResponseRedirect('/')

    else:
        messages.error(self.request,'This is not a POST method.')

    return render(request, 'home.html', context)


def job_hist(request):
    """renders the job history page"""
   
    my_username, my_group, my_home, my_uid, my_id = my_info(request)

    # history card -> uses my_uid
    myjobhist = CarmeJobTable.objects.filter(state__gte=3, id_user__exact=my_uid).order_by('-time_end')[:20]
    myslurmid_list = list(myjobhist.values_list('id_job', flat=True))
    
    cases = [When(slurm_id=foo, then=sort_order) for sort_order, foo in enumerate(myslurmid_list)]
    myslurmjob = SlurmJob.objects.filter(slurm_id__in=myslurmid_list).annotate(
        sort_order=Case(*cases, output_field=IntegerField())).order_by('sort_order')
    
    mylist_long  = zip( list(myjobhist), list(myslurmjob) ) # last 20

    # compute total GPU hours -> uses my_uid
    job_time_end = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=my_uid).aggregate(Sum('time_end'))['time_end__sum']
    job_time_start = CarmeJobTable.objects.filter(
        state__gte=3, id_user__exact=my_uid).aggregate(Sum('time_start'))['time_start__sum']
    job_time = 0
    if (job_time_start and job_time_end):
        job_time = round((job_time_end-job_time_start)/3600)

    # render template
    context = {
        # config ----------------------------------------------------
        'CARME_VERSION': settings.CARME_VERSION,
        'CARME_USERS':settings.CARME_USERS,
        # user info -------------------------------------------------
        'CARME_USER': my_username,
        'CARME_GROUP': my_group,
        # history data ----------------------------------------------
        'myjobhist': myjobhist,
        'myslurmjob': myslurmjob,
        'mylist_long': mylist_long,
        'job_time': job_time,
    }

    return render(request, 'job_hist.html', context)


def job_info(request):
    """ renders the job info modal page"""

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


def stop_job(request):
    """stopping a job (handing request to backend)"""

    if request.method == 'POST':
        # create a form instance and populate it with data from the request:
        form = StopJobForm(request.POST)

        # check whether it's valid:
        if form.is_valid():
            jobID = form.cleaned_data['jobID']
            jobName = form.cleaned_data['jobName']
            jobUser = form.cleaned_data['jobUser']

            # backend call
            conn = rpyc.ssl_connect(settings.CARME_BACKEND_NODE, settings.CARME_BACKEND_PORT, keyfile=settings.BASE_DIR+"/SSL/frontend.key",
                                    certfile=settings.BASE_DIR+"/SSL/frontend.crt")
            
            if conn.root.cancel(str(jobID), str(jobUser)) != 0:
                print("Error stopping job {} from user {}".format(jobID, jobUser))
                raise Exception("ERROR stopping job [backend]")

            return HttpResponseRedirect('/carme/JobTable/')
        else:
            return HttpResponse('<h3>Error - Invalid Form: {}</h3>'.format(form.cleaned_data['jobUser']))

    return HttpResponse('')  # HttpResponseRedirect('/')


def messages(request):
    """generate list of user messages"""

    message_list = list(CarmeMessage.objects.filter(user__exact=request.user.username).order_by('-id'))[:10] # select only 10 latest messages
    message_list.reverse() # reverse message list for correct appendance on update
    
    # render template
    context = {
        'message_list': message_list,
    }

    return render(request, 'blocks/messages.html', context)

def proxy_auth(request):
    """authenticates connection requests (called py proxy)"""

    if "HTTP_X_FORWARDED_PREFIX" in request.META:
        path = request.META["HTTP_X_FORWARDED_PREFIX"] # in case of theia strip-prefix sets the prefix
    elif "HTTP_X_FORWARDED_URI" in request.META:
        path = request.META["HTTP_X_FORWARDED_URI"] # in normal cases the uri is used

    #if request.user.is_superuser: # superusers can access every job
    return HttpResponse(status=200) # should go within if condition for multi-user carme
    #elif len(path) > 0:
    #    first = path[1:].split("/")[0] # [1:] removes / from beginning

    #    if first.startswith("nb_") or first.startswith("ta_") or first.startswith("tb_"):
    #        url_suffix = first[3:] # remove prefix part
    #        jobs = SlurmJob.objects.filter(url_suffix__exact=url_suffix, user__exact=request.user, status__exact="running")

    #        if(len(jobs) > 0):
    #            return HttpResponse(status=200) # ok
   
    #return HttpResponse(status=403) # forbidden

#####################################
######## Starts HighCharts ##########
#####################################

class BaseForecast():
    xAxispoints = 8 #choose number of points
    
    try:
        acceleratorQuery = Accelerator.objects.filter()                                                                                                                        
        accelerator_name = list(acceleratorQuery.order_by('id').values_list('name',flat=True))
        accelerator_name = list({value:"" for value in accelerator_name}) # remove duplicates 
                                                                                      
        accelerator_type = []                                                                                                                       
        for num in range(len(accelerator_name)):                                                                           
            # type                                                                                                         
            acceleratorNameQuery=Accelerator.objects.filter(name__exact=accelerator_name[num]) # e.g., all GTXs            
            accelerator_type_single = acceleratorNameQuery.order_by('id').values_list('type',flat=True).first()            
            accelerator_type.append(accelerator_type_single)
    except:
        accelerator_name = []
        accelerator_type = []

    def get_providers(self):
        return ["Free", "Used", "Queued" ]
    
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
                "value": "0.5", 
            }]        
        }

    def get_markers(self):
        return [ {"symbol": 'circle', "radius":4.5},
                 {"symbol": 'square', "radius":3.9},
                 {"symbol": 'diamond', "radius":5}  ]
    
    title = _("") # Title shows None if removed
    #y_axis_title = _("Accelerator")  

    credits = {
        "enabled": False, # Credits show highcharts.com if removed
        "text": "Christian Ortiz",
    }

    def get_base_data(self):
       
        run_sortedfuture=[]
        queue_sortedfuture=[]

        try:
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
        
            accs = accelerator_name
            numaccs = accelerator_name_num_total
        except:
            accs = []
            numaccs = []

        for k in range(len(accs)):

            run_accs = np.asarray(SlurmJob.objects.filter(
                status__exact='running', gpu_type__exact=accs[k]).values_list('slurm_id','num_nodes','num_gpus','gpu_type').order_by('slurm_id') or [('0','0','0',accs[k])])
            run_accs[:,2] = run_accs[:,1].astype(int)*run_accs[:,2].astype(int)
            run_accs = np.delete(run_accs, 1, 1)  # (slurm_id, num_gpus = num_gpus * num_nodes, gpu_type)  
            run_time = np.asarray(CarmeJobTable.objects.filter(
                id_job__in=run_accs[:,0]).values_list('timelimit','time_start').order_by('id_job') or [(0,0)])
            run_future = np.c_[run_accs[:,1],60*run_time[:,0]+run_time[:,1]] # (num_gpus in run, time_end)
            run_sortedfuture.append(np.array(sorted(run_future.astype(int),key=lambda x: x[1]))) # sorted by time_end 
                
            queue_accs = np.asarray(SlurmJob.objects.filter(
                status__exact='queued', gpu_type__exact=accs[k]).values_list('slurm_id','num_nodes','num_gpus','gpu_type').order_by('slurm_id') or [('0','0','0',accs[k])])
            queue_accs[:,2] = queue_accs[:,1].astype(int)*queue_accs[:,2].astype(int)
            queue_accs = np.delete(queue_accs, 1, 1) # (slurm_id, num_gpus = num_gpus * num_nodes, gpu_type) 
            queue_time = np.asarray(CarmeJobTable.objects.filter(
                id_job__in=queue_accs[:,0]).values_list('timelimit','time_submit').order_by('id_job') or [(0,0)])
            queue_future = np.c_[queue_accs[:,1],queue_time[:,1],queue_time[:,0]] # (num_gpus in queue, time_submit, timelimit)
            queue_sortedfuture.append(np.array(sorted(queue_future.astype(int),key=lambda x: x[1]))) # sorted by time_submit 
        
        # Initial state
        free_0 = []
        queue_0 = []
        used_0 = []
        for k in range(len(accs)):
            free_0.append(numaccs[k] - sum(run_sortedfuture[k][:,0])) # free accs
            queue_0.append(sum(queue_sortedfuture[k][:,0])) # queue accs
            used_0.append(numaccs[k] - free_0[k]) # used accs

        forecast = [] 
        for k in range(len(accs)):
            if queue_sortedfuture[k][0,1]==0: 
                forecast.append(np.zeros((len(run_sortedfuture[k]), 6)).astype(int))
            else:
                forecast.append(np.zeros((len(run_sortedfuture[k])+len(queue_sortedfuture[k]),6)).astype(int))

        # Calculation starts
        for k in range(len(accs)):

            # time = 0: when first running job ends 
            run_sortedfuture[k][0,0] = free_0[k] + run_sortedfuture[k][0,0] # free accs at t=0
            
            # time = 0: processing queued jobs
            for j in range(len(queue_sortedfuture[k])):
                if queue_sortedfuture[k][j,1] <= run_sortedfuture[k][0,1]: # time_submit <= time_end  
                    if queue_sortedfuture[k][j,0] <= run_sortedfuture[k][0,0]: # num_accs_queued <= num_accs_running
                        if queue_sortedfuture[k][j,0] != 0:
                            run_sortedfuture[k][0,0] = run_sortedfuture[k][0,0] - queue_sortedfuture[k][j,0] # free accs at t=0
                            # jth-queued job listed in new_run as a new running job
                            new_run = np.array([[queue_sortedfuture[k][j,0],60*queue_sortedfuture[k][j,2] + run_sortedfuture[k][0,1]]])  
                            run_sortedfuture[k] = np.r_[run_sortedfuture[k],new_run]
                            run_sortedfuture[k] = np.array(sorted(run_sortedfuture[k],key=lambda x: x[1])) # jobs running including new_run
                            queue_sortedfuture[k][j,0] = 0

            # time = 0: after processing queued jobs
            forecast[k][0,0] = run_sortedfuture[k][0,0] # free accs at t=0
            forecast[k][0,1] = sum(queue_sortedfuture[k][:,0]) # queue accs at t=0
            forecast[k][0,2] = numaccs[k] - forecast[k][0,0] # used accs at t=0
            forecast[k][0,3] = forecast[k][0,0] - free_0[k] # free per time 
            forecast[k][0,4] = forecast[k][0,1] - queue_0[k] # queue per time 
            forecast[k][0,5] = forecast[k][0,2] - used_0[k] # used per time 

            # time > 0
            for i in range(1,len(forecast[k])):

                # time > 0: when next running job ends 
                run_sortedfuture[k][i,0] = run_sortedfuture[k][i-1,0] + run_sortedfuture[k][i,0] # free accs at t_i

                # time > 0: processing queued jobs
                for j in range(len(queue_sortedfuture[k])):
                    if queue_sortedfuture[k][j,1] <= run_sortedfuture[k][i,1]:
                        if queue_sortedfuture[k][j,0] <= run_sortedfuture[k][i,0]:
                            if queue_sortedfuture[k][j,0] != 0:
                                run_sortedfuture[k][i,0] = run_sortedfuture[k][i,0] - queue_sortedfuture[k][j,0] # free accs at t_i
                                # jth-queued job listed in new_run as a new running job
                                new_run = np.array([[queue_sortedfuture[k][j,0],60*queue_sortedfuture[k][j,2] + run_sortedfuture[k][i,1]]])  
                                run_sortedfuture[k] = np.r_[run_sortedfuture[k],new_run]
                                run_sortedfuture[k] = np.array(sorted(run_sortedfuture[k],key=lambda x: x[1])) # jobs running including new_run
                                queue_sortedfuture[k][j,0] = 0

                # time > 0: after processing queued jobs                
                forecast[k][i,0] = run_sortedfuture[k][i,0] # free accs at t_i        
                forecast[k][i,1] = sum(queue_sortedfuture[k][:,0]) # queue accs at t_i 
                forecast[k][i,2] = numaccs[k] - forecast[k][i,0] # used accs at t_i 
                forecast[k][i,3] = forecast[k][i,0] - forecast[k][i-1,0] # free per time
                forecast[k][i,4] = forecast[k][i,1] - forecast[k][i-1,1] # queue per time
                forecast[k][i,5] = forecast[k][i,2] - forecast[k][i-1,2] # used per time
        
        ### Compute Single Forecast (chart for each accelerator name) 
        forecast_single = [np.c_[forecast[k],run_sortedfuture[k][:,1],run_sortedfuture[k][:,1]] for k in range(len(accs))] # add time_end (doubled)
        forecast_single = [forecast_single[k][:,[0,1,2,6,7]] for k in range(len(accs))] # free / queue / used / time_end / time_end
        forecast_single = [np.array(sorted(forecast_single[k],key=lambda x: x[3])) for k in range(len(accs)) ] # sort by time_end
        forecast_single = [forecast_single[k].astype(str) for k in range(len(accs)) ] # convert to string        
        
        for k in range(len(accs)): # Express time in ECT datetime
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
            
        for k in range(len(accs)):
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



        ### Compute Total Forecast (chart for all accelerator names) 
        forecast_total = np.concatenate([np.c_[forecast[k],run_sortedfuture[k][:,1],run_sortedfuture[k][:,1]] for k in range(len(accs))]) # add time_end (doubled)
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

    def get_y_axis_options(self):
        y_axis_title = BaseForecast().accelerator_type[self.k].upper()+"s"
        return {"title": {"text": u"%s" % y_axis_title}, }

    def get_labels(self):
        dates = list(BaseForecast().get_base_data()[self.k][:self.xAxispoints,3]) 
        return dates

    def get_data(self): 
        
        free = list(map(int,BaseForecast().get_base_data()[self.k][:self.xAxispoints,0])) 
        queued = list(map(int,BaseForecast().get_base_data()[self.k][:self.xAxispoints,1]))
        used = list(map(int,BaseForecast().get_base_data()[self.k][:self.xAxispoints,2]))  
        
        return [free,used,queued]

if (len(BaseForecast().accelerator_name)) == 0:
    pass
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
