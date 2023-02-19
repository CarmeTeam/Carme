from django import forms
from django.core.exceptions import NON_FIELD_ERRORS
from .models import Project

class CreateProjectForm(forms.ModelForm):
    class Meta:
        model = Project
        
        # field order
        fields = ['num','name','description','department','classification','information','checked']

        # field labels            
        labels = {  'num':'ID',
                    'name':'Name',
                    'checked': 'Checked',
                    'department':'Department',
                    'description':'Description',
                    'information':'Information',
                    'classification':'Classification',
                 }

        # field choices
        CHOICES_CLASSIFICATION = (('Public', 'Public'),
                                  ('Internal', 'Internal'),
                                  ('Confidential', 'Confidential'),
                                  ('Highly Confidential', 'Highly Confidential'),
                                 )

        CHOICES_DEPARTMENT = (('Optimierung', 'Optimierung'),
                              ('Finanzmathematik', 'Finanzmathematik'),
                              ('Transportvorgänge', 'Transportvorgänge'),
                              ('High Performance Computing', 'High Performance Computing'),
                              ('Strömungs- und Materialsimulation', 'Strömungs- und Materialsimulation'),
                              ('Systemanalyse, Prognose und Regelung', 'Systemanalyse, Prognose und Regelung'),
                              ('Materialcharakterisierung und Prüfung', 'Materialcharakterisierung und -prüfung'),
                              ('Mathematik für die Fahrzeugentwicklung', 'Mathematik für die Fahrzeugentwicklung'),
                             )

        
        # field attributes
        widgets = {'checked': forms.CheckboxInput(attrs={"id":'id_checked',"class": "fs-0 fw-400 text-body"}),

                   'num': forms.TextInput(attrs={"id":'id_num',"class": "fs-0 fw-400 text-body form-control","autocomplete": "do-not-autofill",  
                                                 "placeholder":"Project number","maxlength":50 }),
                   'name': forms.TextInput(attrs={"id":'id_name',"class": "fs-0 fw-400 text-body form-control","autocomplete": "do-not-autofill", 
                                                  "placeholder":"Project name","maxlength":50 }),

                   'description': forms.TextInput(attrs={"id":'id_description',"class": "fs-0 fw-400 text-body form-control","autocomplete": "do-not-autofill", 
                                                         "placeholder":"A brief description of your project","maxlength":70 }),
                   'information': forms.Textarea(attrs={"id":'id_information',"class": "fs-0 fw-400 text-body form-control","autocomplete": "do-not-autofill",
                                                        "placeholder":"Write down the resources that you need","maxlength":350, 
                                                        "cols":40,"rows":3}),

                   'department': forms.Select(choices=CHOICES_DEPARTMENT, attrs={"id":'id_department','class':'form-select bg-transparent text-body'}),
                   'classification': forms.Select(choices=CHOICES_CLASSIFICATION, attrs={"id":'id_classification','class':'form-select bg-transparent text-body'}), 
                  }


class UpdateProjectForm(forms.ModelForm):

    class Meta:
        model = Project
        fields = ('num', 'name', 'description','department','classification','information','date_created','date_updated')

        labels = {  'num':'ID',
                    'name':'Name',
                    'department':'Department',
                    'description':'Description',
                    'information':'Information',
                    'classification':'Classification',
                    'date_created': 'Created on',
                    'date_updated': 'Updated on',
                 }

        widgets = { 'num': forms.TextInput(attrs={'id':'id_num','class': 'fs-0 fw-400 text-body form-control','maxlength':50 }),
                    'name': forms.TextInput(attrs={'id':'id_name','class':'fs-0 fw-400 text-body form-control', 'maxlength':50}),
                    'description': forms.TextInput(attrs={'id':'id_description','class':'fs-0 fw-400 text-body form-control', 'maxlength':70}),
                    'department': forms.TextInput(attrs={'id':'id_department','class':'fs-0 fw-400 text-body form-control'}),
                    'classification': forms.TextInput(attrs={'id':'id_classification','class':'fs-0 fw-400 text-body form-control'}),
                    'information': forms.Textarea(attrs={'id':'id_information','class':'fs-0 fw-400 text-body form-control','cols': 40, 'rows': 3}),
                    'date_created': forms.DateInput(attrs={'id':'id_date_created','class':'fs-0 fw-400 text-body form-control','format': 'd-m-Y','type':'date'}),
                    'date_updated': forms.DateInput(attrs={'id':'id_date_updated','class':'fs-0 fw-400 text-body form-control','format': 'd-m-Y','type':'date'}),
                  }

    def __init__(self, *args, **kwargs):
        super(UpdateProjectForm, self).__init__(*args, **kwargs)
        self.fields['num'].disabled = True
        self.fields['name'].disabled = True
        self.fields['department'].disabled = True
        self.fields['information'].disabled = True
        self.fields['date_created'].disabled = True
        self.fields['date_updated'].disabled = True
        self.fields['classification'].disabled = True
