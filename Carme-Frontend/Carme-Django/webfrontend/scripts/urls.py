#from django.conf.urls import url
from django.conf import settings
from django.contrib import admin
#from django.contrib.auth import views as auth_views
#from django.views.generic.base import TemplateView
from django.urls import include, path #, re_path
from django.conf.urls.static import static
from two_factor.urls import urlpatterns as tf_urls

urlpatterns = [
    path('', include('carme.urls'), name='home'),
    path('', include(tf_urls)),
    path('logout/', include('carme.urls'), name='logout'),
    path('carme/', include('carme.urls')),
    path('notifications/', include('django_nyt.urls')), # not used
    path('wiki/', include('wiki.urls')),
    path('admin/', admin.site.urls),
    path('projects/',include('projects.urls',namespace='projects')),
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
