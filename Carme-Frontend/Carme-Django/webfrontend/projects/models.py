import uuid
import misaka

from django.db import models
from django.urls import reverse
from django.utils import timezone
from django.utils.text import slugify
from django.contrib.auth.models import User
from django.db.models import UniqueConstraint

class Project(models.Model):
    name = models.CharField(max_length=255, unique=False)
    slug = models.SlugField(allow_unicode=True, unique=True)
    is_approved = models.BooleanField(default=False) 
    description = models.TextField(blank=True, default='')
    description_html = models.TextField(editable=False, default='', blank=True)
    classification = models.TextField(default='Internal')
    information = models.TextField(blank=True, default='')
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='project_owner')
    date_updated = models.DateTimeField(default=timezone.now)
    date_created = models.DateTimeField(default=timezone.now)
    members = models.ManyToManyField(User,through="ProjectMember")

    def __str__(self):
        name = slugify(self.name)
        return f"{self.owner} --> {name}"

    def get_random_code():
        code = str(uuid.uuid4())[:8].replace('-', '').lower()
        return code

    def save(self, *args, **kwargs):
        if not self.id:
            self.slug = slugify(self.name + " " + str(Project.get_random_code()))
            self.description_html = misaka.html(self.description)
        else:
            orig = Project.objects.get(pk=self.pk)
            if orig.name != self.name:
                self.slug = slugify(self.name + " " + str(Project.get_random_code()))

        return super(Project, self).save(*args, **kwargs)

    def get_absolute_url(self):
        return reverse("projects:join", kwargs={"slug": self.slug})
      
    class Meta:
        ordering = ["name"]
        constraints = [
            UniqueConstraint(
                 fields=['name', 'owner'], 
                 name='unique_project_name',
                 #violation_error_message='your_error_message'
            )
        ]


STATUS_CHOICES = (
    ('none', 'none'),
    ('sent', 'sent'),
    ('accepted', 'accepted')
)

class ProjectMember(models.Model):
    user = models.ForeignKey(User,on_delete=models.CASCADE,)
    project = models.ForeignKey(Project,on_delete=models.CASCADE,)
    status = models.CharField(max_length=8, choices=STATUS_CHOICES, default="none")
    is_manager = models.BooleanField(default=False)
    is_approved_by_manager = models.BooleanField(default=False)
    is_approved_by_admin = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.project}-{self.user}-{self.status}"

    class Meta:
        unique_together = ("project", "user")

# Project -- (ProjectHasTemplate) -- ResourceTemplate
class ResourceTemplate(models.Model):
    name = models.CharField(max_length=255, unique=True)
    maxjobs = models.IntegerField(default=4)
    maxnodes_per_job = models.CharField(max_length=50, default="1")
    maxaccels_per_node = models.CharField(max_length=50, default="1")
    walltime = models.IntegerField(default=3)
    partition = models.CharField(max_length=255)
    features = models.TextField(blank=True, default='')
    template = models.ManyToManyField(Project,through="ProjectHasTemplate")

    def __str__(self):
        return self.name


class ProjectHasTemplate(models.Model):
    project = models.ForeignKey(Project,on_delete=models.CASCADE,)
    template = models.ForeignKey(ResourceTemplate,on_delete=models.CASCADE,)
    
    def __str__(self):
        return f"{self.project}-{self.template}"

    class Meta:
        unique_together = ("project", "template")


# ResourceTemplate -- (TemplateHasAccelerator) -- Accelerator
class Accelerator(models.Model):
    name = models.CharField(max_length=255, unique=True)
    type = models.CharField(max_length=50, default="NONE")
    num_total = models.IntegerField(default=0)
    num_per_node = models.IntegerField(default=0)
    num_cpus_per_acc = models.IntegerField(default=0)
    num_ram_per_acc = models.IntegerField(default=0)
    accelerator = models.ManyToManyField(ResourceTemplate,through="TemplateHasAccelerator")

    def __str__(self):
        return f"{self.type}-{self.name}"


class TemplateHasAccelerator(models.Model):
    resourcetemplate = models.ForeignKey(ResourceTemplate,on_delete=models.CASCADE,)
    accelerator = models.ForeignKey(Accelerator,on_delete=models.CASCADE,)
    
    def __str__(self):
        return f"{self.resourcetemplate}-{self.accelerator}"

    class Meta:
        unique_together = ("resourcetemplate", "accelerator")
