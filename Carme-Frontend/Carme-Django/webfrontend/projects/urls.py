from django.urls import path
from . import views

app_name = 'projects'

urlpatterns = [
    path('', views.ListProjects.as_view(), name="all"),
    # project classes:
    path("create/", views.CreateProject.as_view(), name="create"),
    path("join/<slug>/",views.JoinProject.as_view(), name="join"),
    path("leave/<slug>/",views.LeaveProject.as_view(), name="leave"),
    path("detail/<slug>/",views.SingleProject.as_view(),name="single"),
    path("delete/<slug>/",views.DeleteProject.as_view(), name="delete"),
    path("update/<slug>/",views.UpdateProject.as_view(), name="update"),
    # membership methods:
    path('set/manager/', views.set_as_manager, name='set-manager'),
    path('invitation/submit/', views.submit_invitation, name='submit-invitation'),
    path('invitation/accept/', views.accept_invitation, name='accept-invitation'),
    path('invitation/reject/', views.reject_invitation, name='reject-invitation'),
]
