import uuid
import misaka

from django.db import models
from django.urls import reverse
from django.utils import timezone
from django.utils.text import slugify
from django.contrib.auth.models import User
from django.db.models import UniqueConstraint

class Project(models.Model):
    # input
    checked = models.BooleanField(default=False)
    is_approved = models.BooleanField(default=False)
    num = models.CharField(max_length=255, unique=False)  
    name = models.CharField(max_length=255, unique=False)
    type = models.CharField(max_length=255, unique=False, default="none")
    slug = models.SlugField(allow_unicode=True, unique=True)
    department = models.CharField(max_length=255, unique=False)
    classification = models.CharField(max_length=255, unique=False)
    # textarea
    information = models.TextField(default='', blank=True)  
    description = models.TextField(default='', blank=True)
    description_html = models.TextField(editable=False, default='', blank=True)
    # dates
    date_updated = models.DateTimeField(null=True, blank=True)
    date_expired = models.DateTimeField(null=True, blank=True) 
    date_approved = models.DateTimeField(null=True, blank=True)
    date_created = models.DateTimeField(default=timezone.now)
    # foreign keys
    members = models.ManyToManyField(User,through="ProjectMember")
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='project_owner') 

    def __str__(self):
        name = slugify(self.name)
        return f"{self.owner} --> {name}"

    def get_random_code():
        code = str(uuid.uuid4())[:8].replace('-', '').lower()
        return code

    def save(self, *args, **kwargs):
        if not self.id:
            if len(self.name) > 20:
                short_name = self.name[:20]
            else:
                short_name = self.name
            self.slug = slugify(str(self.owner) + " " + short_name + " " + str(Project.get_random_code()))
            self.description_html = misaka.html(self.description)
        else:
            orig = Project.objects.get(pk=self.pk)
            self.description_html = misaka.html(self.description)
            if orig.name != self.name:
                # This should never happen! If it does, there is an error
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
    type = models.CharField(max_length=255, unique=False, default="none")
    maxjobs = models.IntegerField(default=4)
    maxnodes_per_job = models.IntegerField(default=1)
    maxaccels_per_node = models.IntegerField(default=1)
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
    name = models.CharField(max_length=255, default="none")
    type = models.CharField(max_length=50, default="none")
    num_per_node = models.IntegerField(default=0)
    num_cpus_per_node = models.IntegerField(default=0)
    main_mem_per_node = models.IntegerField(default=0)
    node_name = models.CharField(max_length=255, unique=True, default="local")
    node_status = models.IntegerField(default=0)
    accelerator = models.ManyToManyField(ResourceTemplate,through="TemplateHasAccelerator")

    def __str__(self):
        return f"{self.name} | {self.node_name} | node status = {self.node_status}"


class TemplateHasAccelerator(models.Model):
    resourcetemplate = models.ForeignKey(ResourceTemplate,on_delete=models.CASCADE,)
    accelerator = models.ForeignKey(Accelerator,on_delete=models.CASCADE,)
    
    def __str__(self):
        return f"{self.resourcetemplate} | {self.accelerator}"

    class Meta:
        unique_together = ("resourcetemplate", "accelerator")

# ResourceTemplate -- (TemplateHasImage) -- Image
class Image(models.Model):
    name = models.CharField(max_length=255, unique=True, default="Base")
    type = models.CharField(max_length=255, unique=False, default="carme")
    path = models.CharField(max_length=255, default='')
    information = models.TextField(blank=True, default='')
    status = models.BooleanField(default=False)
    owner = models.CharField(max_length=50, default='admin')
    image = models.ManyToManyField(ResourceTemplate,through="TemplateHasImage")
    bind = models.CharField(max_length=255, unique=False, default="none")

    def __str__(self):
        return f"{self.name}-{self.type}"

class TemplateHasImage(models.Model):
    resourcetemplate = models.ForeignKey(ResourceTemplate,on_delete=models.CASCADE,)
    image = models.ForeignKey(Image,on_delete=models.CASCADE,)

    def __str__(self):
        return f"{self.resourcetemplate}-{self.image}"

    class Meta:
        unique_together = ("resourcetemplate", "image")

# Image -- (ImageHasFlag) -- Flag
class Flag(models.Model):
    name = models.CharField(max_length=255, unique=True, default="none")
    type = models.CharField(max_length=255, unique=False, default="none")
    flag = models.ManyToManyField(Image,through="ImageHasFlag")

    def __str__(self):
        return f"{self.name}-{self.type}"

class ImageHasFlag(models.Model):
    image = models.ForeignKey(Image,on_delete=models.CASCADE,)
    flag = models.ForeignKey(Flag,on_delete=models.CASCADE,)

    def __str__(self):
        return f"{self.image}-{self.flag}"

    class Meta:
        unique_together = ("image", "flag")
