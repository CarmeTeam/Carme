from django.contrib import admin
from . import models

class ProjectMemberInline(admin.TabularInline):
    model = models.ProjectMember

@admin.register(models.ProjectHasTemplate)
class ProjectHasTemplateAdmin(admin.ModelAdmin):
    list_display = ('get_name', 'template','get_approved','get_owner')

    @admin.display(description='project name')
    def get_name(self, obj):
        return obj.project.name

    @admin.display(ordering='project__owner', description='owner')
    def get_owner(self, obj):
        return obj.project.owner

    @admin.display(description='is approved', boolean=True)
    def get_approved(self, obj):
        return obj.project.is_approved

@admin.register(models.Project)
class ProjectAdmin(admin.ModelAdmin):
    list_display = ('name', 'slug','is_approved','owner')
    ordering = ('owner',)

admin.site.register(models.ProjectMember)
admin.site.register(models.ResourceTemplate)
admin.site.register(models.Accelerator)
admin.site.register(models.TemplateHasAccelerator)
