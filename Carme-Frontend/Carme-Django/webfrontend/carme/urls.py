# ---------------------------------------------- 
# Carme
# ----------------------------------------------
# urls.py
#
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# Contact: info@open-carme.org
# ---------------------------------------------
from . import views
from .views import *
from django.contrib import admin
from django.conf import settings
from django.urls import path, include
from projects.models import Accelerator

try:
    acceleratorQuery = Accelerator.objects.filter()                                       
    accelerator_name = list(acceleratorQuery.order_by('id').values_list('name',flat=True))
    accelerator_name = list({value:"" for value in accelerator_name}) # remove duplicates
except:
    accelerator_name = []

urlpatterns = [
    path('', views.index, name='index'),
    path('account/login/', views.myLogin, name='mylogin'),
    path('logout/', views.logout, name='logout'),
    path('StartJob/', views.start_job, name='start_job'),
    path('StopJob/', views.stop_job, name='stop_job'),
    path('JobInfo/', views.job_info, name='job_info'),
    path('JobTable/', views.job_table, name='job_table'),
    path('JobHist/', views.job_hist, name='job_hist'),
    path('proxy_auth/', views.proxy_auth, name='proxy_auth'),
    #path('line_chart_json_time/', line_chart_json_time, name="line_chart_json_time"),
    path('Messages/', views.messages, name='messages'), 
]

if len(accelerator_name)==0:                                                                                                                                  
    pass                                                                                                                        
elif len(accelerator_name)==1:                                                                                                                                
    for i in range(len(accelerator_name)):                                                                                                                    
        exec("urlpatterns.append(path('line_chart_json_forecast"+str(i)+"', line_chart_json_forecast" +str(i)+", name='line_chart_json_forecast"+str(i)+"'))")
else:                                                                                                                                                         
    for i in range(len(accelerator_name)+1):                                                                                                                  
        exec("urlpatterns.append(path('line_chart_json_forecast"+str(i)+"', line_chart_json_forecast" +str(i)+", name='line_chart_json_forecast"+str(i)+"'))")
