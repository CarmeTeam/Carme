from django import forms
from django.core.exceptions import NON_FIELD_ERRORS
from .models import Project

class CreateProjectForm(forms.ModelForm):
    class Meta:
        model = Project
        fields = ("name", "description", "classification", "information")

class ProjectModelForm(forms.ModelForm):
    name = forms.CharField()
    description = forms.CharField()
    classification = forms.CharField()
    date_created = forms.DateField(label='Created on')
    date_updated = forms.DateField(label='Updated on')
    information = forms.CharField(label='Information',widget=forms.Textarea(attrs={'cols': 40, 'rows': 5}))

    class Meta:
        model = Project
        fields = ('name', 'description','classification','date_created', 'date_updated', 'information')

    def __init__(self, *args, **kwargs):
        super(ProjectModelForm, self).__init__(*args, **kwargs)
        self.fields['name'].disabled = True
        self.fields['classification'].disabled = True
        self.fields['date_created'].disabled = True
        self.fields['date_updated'].disabled = True
        self.fields['information'].disabled = True
