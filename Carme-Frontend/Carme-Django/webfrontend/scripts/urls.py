from django.conf.urls import url
from django.contrib import admin
from django.contrib.auth import views as auth_views
from django.views.generic.base import TemplateView
from django.urls import include, path
from django.conf.urls.static import static
from django.conf import settings
#from django.conf.urls import handler400, handler403, handler404, handler500

#handler404 = 'carme-base.views.page_not_found'
#handler500 = 'carme-base.views.error'  

urlpatterns = [
    url(r'^', include('carme-base.urls'), name='home'),
    url(r'^login/$', auth_views.LoginView.as_view(template_name='login.html'), name='login'),
    url(r'^logout/$', auth_views.LogoutView.as_view(template_name='logged_out.html'), name='logout'),
    path('carme-base/', include('carme-base.urls')),
    url(r'^notifications/', include('django_nyt.urls')),
    url(r'^wiki/', include('wiki.urls')),
    path('todo/', include('todo.urls', namespace="todo")),
    path('admin/', admin.site.urls)
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
