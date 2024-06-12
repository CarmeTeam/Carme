from django.contrib import admin
from django.urls import include, path
from django.conf.urls.static import static
from django.conf import settings

urlpatterns = [
    path('', include('carme.urls'), name='home'),
    path('carme/', include('carme.urls')),
    path('admin/', admin.site.urls),
    path('projects/',include('projects.urls',namespace='projects')),
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
