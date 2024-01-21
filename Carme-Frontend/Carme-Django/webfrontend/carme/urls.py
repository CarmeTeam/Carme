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
from django.contrib import admin
from django.urls import path, re_path, include
#from django.conf.urls import url, include
from . import views
from .views import * #line_chart_json, line_chart_json2
from django.conf import settings

from .views import AdminSiteOTPRequiredMixinRedirSetup
admin.site.__class__ = AdminSiteOTPRequiredMixinRedirSetup

from projects.models import Accelerator


acceleratorQuery = Accelerator.objects.filter()                                                                                                                             
accelerator_name = list(acceleratorQuery.order_by('id').values_list('name',flat=True))
accelerator_name = list({value:"" for value in accelerator_name}) # remove duplicates 

#gputype=[]
#for num in range(len(settings.CARME_GPU_NUM.split())):
#    gputype.append(settings.CARME_GPU_NUM.split()[num].split(":")[0])
#        
#gpus = gputype


urlpatterns = [
    path('', views.index, name='index'),
    path('account/two_factor/setup/', views.QRSetup, name='setup'),
    path('account/login/', views.myLogin, name='mylogin'),
    re_path(r'^password/$', views.change_password, name='change_password'),
    re_path(r'^StartJob/$', views.start_job, name='start_job'),
    re_path(r'^StopJob/$', views.stop_job, name='stop_job'),
    re_path(r'^JobInfo/$', views.job_info, name='job_info'),
    re_path(r'^JobTable/$', views.job_table, name='job_table'),
    re_path(r'^JobHist/$', views.job_hist, name='job_hist'),
    re_path(r'^logout/$', views.logout, name='logout'),
    #re_path(r'^login/$', views.custom_login, name='login'),
    path('login/', views.login, name='login'),
    #path('color/', views.color, name='color'),        
    ##path('login/validate', views.login_validate, name='login_validate'),
    re_path(r'^proxy_auth/$', views.proxy_auth, name='proxy_auth'),
    re_path(r'^AdminJobTable/$', views.admin_job_table, name='admin_job_table'),
    re_path(r'^AdminAllJobs/$', views.admin_all_jobs, name='admin_all_jobs'),
    re_path(r'^maintenance-mode/', include('maintenance_mode.urls')),
    path('line_chart_json_time/', line_chart_json_time, name="line_chart_json_time"),
    re_path(r'^Messages/$', views.messages, name='messages'), 
]

if len(accelerator_name)==0:
    print('No accelerators available')
elif len(accelerator_name)==1:
    for i in range(len(accelerator_name)):
        exec("urlpatterns.append(path('line_chart_json_forecast"+str(i)+"', line_chart_json_forecast" +str(i)+", name='line_chart_json_forecast"+str(i)+"'))")
else:
    for i in range(len(accelerator_name)+1):
        exec("urlpatterns.append(path('line_chart_json_forecast"+str(i)+"', line_chart_json_forecast" +str(i)+", name='line_chart_json_forecast"+str(i)+"'))")
