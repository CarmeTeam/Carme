from django.shortcuts import render, redirect, get_object_or_404

from django.contrib import messages
from django.contrib.auth import get_user_model
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.decorators import login_required 

from projects.models import Project, ProjectMember, ProjectHasTemplate, TemplateHasAccelerator
from django.views.generic import CreateView, DetailView, UpdateView, RedirectView, DeleteView, ListView

from django.http import Http404, HttpResponseRedirect
from django.utils import timezone
from django.urls import reverse, reverse_lazy

from django.db import IntegrityError
from django.db.models import Sum, Count, Case, When, Q, Value, CharField

from .forms import UpdateProjectForm, CreateProjectForm


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
        
        if form.instance.checked:
            form.instance.owner = self.request.user
            try:
                response = super(CreateProject, self).form_valid(form)
                messages.success(self.request, 'Project succesfully created.')
                return response
            except IntegrityError:
                messages.error(self.request,'Project name already exists. Choose a different one.')
                return super().form_invalid(form)
        else:
            messages.error(self.request,'You have to accept the terms and conditions.')
            return super().form_invalid(form)
        

class SingleProject(LoginRequiredMixin,DetailView):
    model = Project

    def get(self, request, *args, **kwargs):
        try:
            return super().get(request, *args, **kwargs)
        except Http404:
            messages.error(self.request,'Project ID doest not exist.')
            return redirect(reverse("projects:all"))

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        slug = self.kwargs.get('slug')

        ### Resources Forms ###
        # template list
        templateQuerySet = ProjectHasTemplate.objects.values('template__name',
                                                             'template__maxjobs',
                                                             'template__maxnodes_per_job',
                                                             'template__maxaccels_per_node',
                                                             'template__walltime',
                                                             'template__partition',
                                                             'template__features')
        templateQuerySet = templateQuerySet.filter(project__name=self.object.name)
        context['template_list'] = templateQuerySet


        # accelerator list
        acceleratorQuerySet = TemplateHasAccelerator.objects.values('accelerator__name',
                                                                    'accelerator__type',
                                                                    'resourcetemplate__name')
        #.filter(resourcetemplate__name=resource_name)
        context['accelerator_list'] = acceleratorQuerySet
        

        ### Members ###

        # Step 1: user list to send an invitation
        User = get_user_model()
        context['user_list'] = User.objects.all()

        # Step 2:
        membersQuery = ProjectMember.objects.filter(project__slug=slug
                                                     ).annotate(member_status=
                                                        Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=Value('actives')),
                                                        default=Value('inactives'))
                                                     )

        # Step 3: Set if request.user is active or inactive member
        is_memberQuery = ProjectMember.objects.filter(project__slug=slug,user=self.request.user
                                                     ).annotate(member_status=
                                                        Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=Value('active')),
                                                        default=Value('inactive'))
                                                     )

        # Step 4: Count active/inactive members in project
        countQuery = ProjectMember.objects.filter(project__slug=slug).values('project__name'
                                                 ).annotate(active_members=Count(
                                                    Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=1))
                                                )).annotate(inactive_members=Count(
                                                    Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False) | Q(status='sent'), then=1))
                                                ))

        context['member_list'] = membersQuery
        context['is_member'] = is_memberQuery
        context['count_list'] = countQuery

        return context 

class ListProjects(LoginRequiredMixin,ListView):
    model = Project

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        myself = self.request.user
        
        # Step 1: List my projects for each group 
        projectQueryActive = ProjectMember.objects.filter(user=myself, status='accepted', is_approved_by_manager=True, is_approved_by_admin=True)
        my_project_list_active=list(set(projectQueryActive.values_list('project', flat=True)))
        
        projectQueryWaiting = ProjectMember.objects.filter(user=myself, status='accepted', is_approved_by_manager=True, is_approved_by_admin=False)
        my_project_list_waiting=list(set(projectQueryWaiting.values_list('project', flat=True)))

        projectQueryReceived = ProjectMember.objects.filter(user=myself, status='sent', is_approved_by_manager=True)
        my_project_list_received=list(set(projectQueryReceived.values_list('project', flat=True)))

        projectQueryRequested = ProjectMember.objects.filter(user=myself, status='sent', is_approved_by_manager=False)
        my_project_list_requested=list(set(projectQueryRequested.values_list('project', flat=True)))
 
        # Step 2: Filter all members in my projects for each group
        memberQueryActive = ProjectMember.objects.filter(project__in=my_project_list_active)
        memberQueryWaiting = ProjectMember.objects.filter(project__in=my_project_list_waiting)
        memberQueryReceived = ProjectMember.objects.filter(project__in=my_project_list_received)
        memberQueryRequested = ProjectMember.objects.filter(project__in=my_project_list_requested)
        
        # Step 3: Count the number of active/inactive members in each project for each group and set a `member_status` field
        countQueryActive = memberQueryActive.values('project__pk','project__name','project__slug','project__description_html',
                                                    'project__owner__username','project__is_approved'
                                                   ).annotate(active_members=Count(
                                                        Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=1))
                                                  )).annotate(inactive_members=Count(
                                                        Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False) | Q(status='sent'), then=1))
                                                  )).annotate(member_status=Value(
                                                        'active', output_field=CharField()
                                                  ))

        countQueryWaiting = memberQueryWaiting.values('project__pk','project__name','project__slug','project__description_html',
                                                      'project__owner__username','project__is_approved'
                                                     ).annotate(active_members=Count(
                                                          Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=1))
                                                    )).annotate(inactive_members=Count(
                                                          Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False) | Q(status='sent'), then=1))
                                                    )).annotate(member_status=Value(
                                                          'waiting', output_field=CharField()
                                                    ))

        countQueryReceived = memberQueryReceived.values('project__pk','project__name','project__slug','project__description_html',
                                                        'project__owner__username','project__is_approved'
                                                       ).annotate(active_members=Count(
                                                            Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=1))
                                                      )).annotate(inactive_members=Count(
                                                            Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False) | Q(status='sent'), then=1))
                                                      )).annotate(member_status=Value(
                                                            'received', output_field=CharField()
                                                      ))

        countQueryRequested = memberQueryRequested.values('project__pk','project__name','project__slug','project__description_html',
                                                          'project__owner__username','project__is_approved'
                                                         ).annotate(active_members=Count(
                                                              Case(When(Q(is_approved_by_admin=True) & Q(is_approved_by_manager=True) & Q(status='accepted'), then=1))
                                                        )).annotate(inactive_members=Count(
                                                              Case(When(Q(is_approved_by_admin=False) | Q(is_approved_by_manager=False) | Q(status='sent'), then=1))
                                                        )).annotate(member_status=Value(
                                                              'requested', output_field=CharField()
                                                        ))

        # Step 4: Join the 4 groups in one Query list
        countQuery = countQueryActive.union(countQueryWaiting,countQueryReceived,countQueryRequested)
        
        managerQueryActive = projectQueryActive.values('project','is_manager')

        context = {
            'project_manager' : managerQueryActive,
            'project_list': countQuery,
        }
        
        return context

class DeleteProject(LoginRequiredMixin, DeleteView):
    """ delete a project """
    model = Project
    template_name = 'projects/project_delete.html'
    success_url = reverse_lazy('projects:all')

    def get_object(self, *args, **kwargs):
        slug = self.kwargs.get('slug')
        project = Project.objects.get(slug=slug)
        return project

    def dispatch(self, request, *args, **kwargs):
        project = self.get_object()
        if project.owner != self.request.user:
            messages.error(self.request,'You need to be the project owner to delete it.')
            return redirect('projects:single', slug=project.slug)
        else:
            messages.success(self.request,'The project was succesfully removed.')
            return super(DeleteProject, self).dispatch(request, *args, **kwargs)


class UpdateProject(LoginRequiredMixin, UpdateView):
    """ update a project """
    template_name = 'projects/project_update.html'
    form_class = UpdateProjectForm
    model = Project
    
    def get_success_url(self, *args, **kwargs):
        return reverse_lazy('projects:single', args=[self.kwargs['slug']])

    def get_object(self, *args, **kwargs):
        slug = self.kwargs.get('slug')
        project = Project.objects.get(slug=slug)
        return project

    def dispatch(self, request, *args, **kwargs):
        project = self.get_object()
        members = ProjectMember.objects.filter(project=project,user=self.request.user)

        if self.request.GET.get('path','') == 'list':
            return HttpResponseRedirect(request.path+"?path=main")

        for member in members:
            if member.is_manager:
                return super(UpdateProject, self).dispatch(request, *args, **kwargs) 

        messages.error(self.request,'You need to be the project admin to update it.')
        return redirect('projects:single', slug=project.slug)

    def form_valid(self, form):
        if form.instance.owner == self.request.user:
            form.instance.date_updated = timezone.now()
            messages.success(self.request, 'Project succesfully updated.')
            return super().form_valid(form)
        else:
            return super().form_invalid(form)


class JoinProject(LoginRequiredMixin, RedirectView):
    """ join an existing project """

    def get_redirect_url(self, *args, **kwargs):
        return reverse("projects:single",kwargs={"slug": self.kwargs.get("slug")})

    def get(self, request, *args, **kwargs):

        try:
            project = get_object_or_404(Project,slug=self.kwargs.get("slug"))
        except Http404:
            messages.error(self.request,'Project ID doest not exist.')
            return redirect('projects:all')


        if self.request.user == project.owner :
            try:
                ProjectMember.objects.create(user=self.request.user,project=project,is_manager=True, 
                                             is_approved_by_admin=True,is_approved_by_manager=True,status="accepted")

            except IntegrityError:
                messages.warning(self.request,"You are already the owner of the project")
                return redirect('projects:all')

            else:
                pass

        else:
            member = ProjectMember.objects.filter(user=self.request.user,project=project)
            if member:
                messages.warning(self.request,"You are already a member of the project")
                return redirect('projects:all') 
            else:
                if request.GET.get('path','') == 'join':
                    messages.warning(self.request,"To join the project, first verify the information and then click on join.")
                    return redirect("projects:single",slug=project.slug) 
                else:
                    ProjectMember.objects.create(user=self.request.user,project=project,status="sent")
                    messages.success(self.request,'You have submitted a request to join the project.')
                
        return super().get(request, *args, **kwargs)



class LeaveProject(LoginRequiredMixin, RedirectView):
    """ leave an existing project """

    def get_redirect_url(self, *args, **kwargs):
        if self.request.get_full_path == self.request.path:
            return reverse("projects:single",kwargs={"slug": self.kwargs.get("slug")})
        else:
            return reverse("projects:all")

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
                "You have successfully left the project."
            )
        return super().get(request, *args, **kwargs)


#################################################
#################### METHODS ####################
#################################################

@login_required
def submit_invitation(request):
    """ submit invitation/request to join a project """

    if request.method=='POST':
        project_pk = request.POST.get('project_pk') # project ID
        user_pk = request.POST.get('user_pk')       # username
        User = get_user_model()
        sender = Project.objects.get(pk=project_pk) # (maybe use slug instead?)
        try:
            receiver = User.objects.get(username=user_pk)
            member = ProjectMember.objects.filter(project=sender,user=receiver)
            if member:
                messages.warning(request,"User '{}' is already a member of the project.".format(user_pk))
            else:
                messages.success(request,"User '{}' was invited to join the project.".format(user_pk))
                ProjectMember.objects.create(project=sender, user=receiver, status='sent', is_approved_by_manager=True)
        except User.DoesNotExist:
            messages.error(request,"User '{}' does not exist. Choose a different one.".format(user_pk))
            receiver = None

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
            messages.warning(request, 'Invitation was accepted. Membership is now waiting for approval.')
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
        messages.success(request, 'Invitation was rejected.')
        return redirect(request.META.get('HTTP_REFERER'))

    return redirect('projects:all')

@login_required
def remove_invitation(request):
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
        messages.success(request, "User '{}' was removed.".format(user_pk))
        return redirect(request.META.get('HTTP_REFERER'))

    return redirect('projects:all')

@login_required
def cancel_invitation(request):
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
        messages.success(request, 'Invitation was cancelled.')
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
            messages.success(request, "User '{}' is now admin of the project.".format(user_pk))
        else:
            rel.is_manager = 0
            messages.success(request, "User '{}' is no longer admin of the project.".format(user_pk))

        rel.save()
        return redirect(request.META.get('HTTP_REFERER'))

    return redirect('projects:all')
