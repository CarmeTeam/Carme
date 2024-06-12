# ----------------------------------------------
# Carme
# ----------------------------------------------
# forms.py
#
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# Contact: info@open-carme.org
# ---------------------------------------------
from django import forms

""" stop job """
class StopJobForm(forms.Form):
    jobID = forms.DecimalField(required=True, widget=forms.HiddenInput())
    jobName = forms.CharField(required=True, widget=forms.HiddenInput())
    jobUser = forms.CharField(required=True, widget=forms.HiddenInput())

""" job info """
class JobInfoForm(forms.Form):
    jobID = forms.DecimalField(required=True, widget=forms.HiddenInput())
