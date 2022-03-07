#from django.conf.urls import url
from django.contrib import admin
from django.contrib.auth import views as auth_views
from django.views.generic.base import TemplateView
from django.urls import include, path, re_path
from django.conf.urls.static import static
from django.conf import settings

urlpatterns = [
    re_path(r'^', include('carme.urls'), name='home'),
    #url(r'^login/$', auth_views.LoginView.as_view(template_name='login.html'), name='login'),
    re_path(r'^logout/$', include('carme.urls'), name='logout'),
    path('carme/', include('carme.urls')),
    re_path(r'^notifications/', include('django_nyt.urls')),
    re_path(r'^wiki/', include('wiki.urls')),
    path('todo/', include('todo.urls', namespace="todo")),
    path('admin/', admin.site.urls)
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
