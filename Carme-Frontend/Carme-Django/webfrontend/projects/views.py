from django.shortcuts import render, redirect, get_object_or_404

from django.contrib import messages
from django.contrib.auth import get_user_model
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.decorators import login_required 

from projects.models import Project, ProjectMember, ProjectHasTemplate, TemplateHasAccelerator
from django.views.generic import CreateView, DetailView, UpdateView, RedirectView, DeleteView, ListView

from django.http import Http404
from django.utils import timezone
from django.urls import reverse, reverse_lazy

from django.db import IntegrityError
from django.db.models import Sum, Count, Case, When, Q

from .forms import ProjectModelForm, CreateProjectForm


#################################################
#################### CLASSES ####################
#################################################

class CreateProject(LoginRequiredMixin, CreateView):
    """ create a project """
    template_name = 'projects/project_create.html'
    form_class = CreateProjectForm
    model = Project

    def form_valid(self, form):
        """ validate form """
        form.instance.owner = self.request.user
        try:
            response = super(CreateProject, self).form_valid(form)
            messages.success(self.request, 'Project succesfully created.')
            return response
        except IntegrityError:
            messages.error(self.request,'Project name already exists. Choose a different one.')
            return super().form_invalid(form)
        

class SingleProject(DetailView):
    """ single project information """
    model = Project

    def get(self, request, *args, **kwargs):
        try:
            return super().get(request, *args, **kwargs)
        except Http404:
            messages.error(self.request,'Project ID doest not exist.')
            return redirect(reverse("projects:all"))

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)

        # User list to add to project
        User = get_user_model()
        context['object_list'] = User.objects.all()

        # Template list
        templateQuerySet = ProjectHasTemplate.objects.values('template__name',
                                                             'template__maxjobs',
                                                             'template__maxnodes_per_job',
                                                             'template__maxaccels_per_node',
                                                             'template__walltime',
                                                             'template__partition',
                                                             'template__features')
        context['template_list'] = templateQuerySet.filter(project__name=self.object.name)

        # Accelerator list
        acceleratorQuerySet = TemplateHasAccelerator.objects.values('accelerator__name',
                                                                    'accelerator__type',
                                                                    'resourcetemplate__name')
        context['accelerator_list'] = acceleratorQuerySet

        # Members list
        slug = self.kwargs.get('slug')
        project_id = Project.objects.get(slug=slug).id
        memberQuerySet = ProjectMember.objects.filter(project_id=project_id)
        countQuerySet = memberQuerySet.values('project__name').annotate(
            active_members=Count(
                Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True), then=1))
            )
        ).annotate(
            inactive_members=Count(
                Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False), then=1))
            )
        )
        context['member_list'] = countQuerySet

        return context
    

class ListProjects(ListView):
    """ list of projects """
    model = Project

    def get_context_data(self, **kwargs):

        # call the base implementation first to get a context
        context = super().get_context_data(**kwargs)
        
        # filter my projects 
        my_project_list_active= []
        my_project_list_waiting= []
        my_project_list_received= []
        my_project_list_requested= []
        
        # Membership: active
        projectQuerySetActive = ProjectMember.objects.filter(user=self.request.user, 
                                                              is_approved_by_admin=True, 
                                                              is_approved_by_manager=True,
                                                              status='accepted')
        
        # Membership: waiting for approval
        projectQuerySetWaiting = ProjectMember.objects.filter(user=self.request.user, 
                                                              is_approved_by_admin=False, 
                                                              is_approved_by_manager=True,
                                                              status='accepted')

        # Membership: invitation received
        projectQuerySetReceived = ProjectMember.objects.filter(user=self.request.user, 
                                                              is_approved_by_manager=True,
                                                              status='sent')
        
        # Membership: invitation requested
        projectQuerySetRequested = ProjectMember.objects.filter(user=self.request.user, 
                                                              is_approved_by_manager=False,
                                                              status='sent')

        for item in projectQuerySetActive:
            my_project_list_active.append(item.project)
        for item in projectQuerySetWaiting:
            my_project_list_waiting.append(item.project)
        for item in projectQuerySetReceived:
            my_project_list_received.append(item.project)
        for item in projectQuerySetRequested:
            my_project_list_requested.append(item.project)    
        
        # filter members in my projects with membership: active
        memberQuerySetActive = ProjectMember.objects.filter(project__in=my_project_list_active)
        # filter members in my projects with membership: waiting
        memberQuerySetWaiting = ProjectMember.objects.filter(project__in=my_project_list_waiting)
        # filter members in my projects with membership:  received
        memberQuerySetReceived = ProjectMember.objects.filter(project__in=my_project_list_received)
        # filter members in my projects with membership: requested
        memberQuerySetRequested = ProjectMember.objects.filter(project__in=my_project_list_requested)
        
        # list project and count members in my projects with membership: active
        countQuerySetActive = memberQuerySetActive.values('project__pk','project__name','project__slug','project__description_html',
                                                          'project__owner__username','project__is_approved'
        ).annotate(
            active_members=Count(
                Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=1))
            )
        ).annotate(
            inactive_members=Count(
                Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False) | Q(status='sent'), then=1))
            )
        )

        isManagerQuerySetActive = projectQuerySetActive.values('project','is_manager')


        # list project and count members in my projects with membership: waiting
        countQuerySetWaiting = memberQuerySetWaiting.values('project__pk','project__name','project__slug','project__description_html',
                                                            'project__owner__username','project__is_approved'
        ).annotate(
            active_members=Count(
                Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=1))
            )
        ).annotate(
            inactive_members=Count(
                Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False) | Q(status='sent'), then=1))
            )
        )

        # list project and count members in my projects with membership: received
        countQuerySetReceived = memberQuerySetReceived.values('project__pk','project__name','project__slug','project__description_html',
                                                              'project__owner__username','project__is_approved'
        ).annotate(
            active_members=Count(
                Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=1))
            )
        ).annotate(
            inactive_members=Count(
                Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False) | Q(status='sent'), then=1))
            )
        )

        # list project and count members in my projects with membership: requested
        countQuerySetRequested = memberQuerySetRequested.values('project__pk','project__name','project__slug','project__description_html',
                                                                'project__owner__username','project__is_approved'
        ).annotate(
            active_members=Count(
                Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=1))
            )
        ).annotate(
            inactive_members=Count(
                Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False) | Q(status='sent'), then=1))
            )
        )
        
        context = {
            'project_list_active' : countQuerySetActive,
            'project_list_waiting' : countQuerySetWaiting,
            'project_list_received' : countQuerySetReceived,
            'project_list_requested' : countQuerySetRequested,
            'project_list_manager' : isManagerQuerySetActive
        }
        
        return context


class DeleteProject(LoginRequiredMixin, DeleteView):
    """ delete a project """
    model = Project
    template_name = 'projects/project_delete.html'
    success_url = reverse_lazy('projects:all')

    def get_object(self, *args, **kwargs):
        slug = self.kwargs.get('slug')
        obj = Project.objects.get(slug=slug)
        return obj


class UpdateProject(LoginRequiredMixin, UpdateView):
    """ update a project """
    form_class = ProjectModelForm
    model = Project
    template_name = 'projects/project_update.html'
    
    def get_success_url(self, *args, **kwargs):
        return reverse_lazy('projects:single', args=[self.kwargs['slug']])

    def form_valid(self, form):
        if form.instance.owner == self.request.user:
            field_value = Project.objects.get(pk=form.instance.pk).date_created
            form.instance.date_created = field_value
            form.instance.date_updated = timezone.now()
            messages.success(self.request, 'Project succesfully updated.')
            return super().form_valid(form)
        else:
            form.add_error(None, 'You need to be the owner of the project to update it.')
            return super().form_invalid(form)


class JoinProject(LoginRequiredMixin, RedirectView):
    """ join an existing project """

    def get_redirect_url(self, *args, **kwargs):
        return reverse("projects:single",kwargs={"slug": self.kwargs.get("slug")})

    def get(self, request, *args, **kwargs):
        project = get_object_or_404(Project,slug=self.kwargs.get("slug"))

        if self.request.user == project.owner :
            try:
                ProjectMember.objects.create(user=self.request.user,project=project,is_manager=True, 
                                             is_approved_by_admin=True,is_approved_by_manager=True,status="accepted")

            except IntegrityError:
                messages.warning(self.request,("Warning, already a member of {}".format(project.name)))

            else:
                pass
        else:
            try:
                ProjectMember.objects.create(user=self.request.user,project=project,status="send")

            except IntegrityError:
                messages.warning(self.request,("Warning, already a member of {}".format(project.name)))

            else:
                pass

        return super().get(request, *args, **kwargs)


class LeaveProject(LoginRequiredMixin, RedirectView):
    """ leave an existing project """

    def get_redirect_url(self, *args, **kwargs):
        return reverse("projects:single",kwargs={"slug": self.kwargs.get("slug")})

    def get(self, request, *args, **kwargs):

        try:
            membership = ProjectMember.objects.filter(
                user=self.request.user,
                project__slug=self.kwargs.get("slug")
            ).get()

        except ProjectMember.DoesNotExist:
            messages.warning(
                self.request,
                "You can't leave this group because you aren't in it."
            )
        else:
            membership.delete()
            messages.success(
                self.request,
                "You have successfully left this group."
            )
        return super().get(request, *args, **kwargs)


#################################################
#################### METHODS ####################
#################################################

@login_required
def send_invitation(request):
    """ submit invitation/request to join a project """

    if request.method=='POST':
        project_pk = request.POST.get('project_pk') # project ID
        user_pk = request.POST.get('user_pk')       # username
        User = get_user_model()
        receiver = User.objects.get(username=user_pk) 
        sender = Project.objects.get(pk=project_pk) # (maybe use slug instead?)
        rel = ProjectMember.objects.create(project=sender, user=receiver, status='sent', is_approved_by_manager=True)

        return redirect(request.META.get('HTTP_REFERER'))
    return redirect('projects:all')

@login_required
def accept_invitation(request):
    """ accept invitation/request to join a project """

    if request.method=="POST":
        project_pk = request.POST.get('project_pk') # project ID
        if 'user_pk' in request.POST:
            user_pk = request.POST.get('user_pk')   # username
            User = get_user_model()
            receiver = User.objects.get(username=user_pk) 
        else:
            receiver = request.user

        sender = Project.objects.get(pk=project_pk) 
        rel = get_object_or_404(ProjectMember, project=sender, user=receiver)

        if rel.status == 'sent':
            if rel.is_approved_by_manager == 0:
                rel.is_approved_by_manager = 1
            rel.status = 'accepted'
            rel.save()
        return redirect(request.META.get('HTTP_REFERER'))

    return redirect('projects:all')

@login_required
def reject_invitation(request):
    """ reject invitation/request to join  project """

    if request.method=="POST":
        project_pk = request.POST.get('project_pk') # project ID
        if 'user_pk' in request.POST:
            user_pk  = request.POST.get('user_pk')  # username
            User = get_user_model()
            receiver = User.objects.get(username=user_pk) 
        else:
            receiver = request.user

        sender = Project.objects.get(pk=project_pk) 
        rel = get_object_or_404(ProjectMember, project=sender, user=receiver)
        rel.delete()
        return redirect(request.META.get('HTTP_REFERER'))

    return redirect('projects:all')

@login_required
def set_as_manager(request):
    """ set user as project manager, a.k.a project admin"""

    if request.method=="POST":
        project_pk = request.POST.get('project_pk') # project ID
        user_pk  = request.POST.get('user_pk')      # username
        User = get_user_model()
        receiver = User.objects.get(username=user_pk) 

        sender = Project.objects.get(pk=project_pk) 
        rel = get_object_or_404(ProjectMember, project=sender, user=receiver)

        if rel.is_manager == 0:
            rel.is_manager = 1
        else:
            rel.is_manager = 0

        rel.save()
        return redirect(request.META.get('HTTP_REFERER'))

    return redirect('projects:all')
