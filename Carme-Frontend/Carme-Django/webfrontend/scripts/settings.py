# ----------------------------------------------------------------------------------------------------------------------------------
# Carme
# ----------------------------------------------------------------------------------------------------------------------------------
# settings.py - central frontend settings
#
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/readme.md
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# Contact: info@open-carme.org
# ----------------------------------------------------------------------------------------------------------------------------------

import os
import logging
from django.urls import reverse_lazy
from importlib.machinery import SourceFileLoader
SourceFileLoader('CarmeConfig.frontend', '/etc/carme/CarmeConfig.frontend').load_module()
from CarmeConfig.frontend import *

# variables ------------------------------------------------------------------------------------------------------------------------

## security
DEBUG = True 
SECRET_KEY = CARME_KEY
ALLOWED_HOSTS = ['*', '10.0.0.27']

## csrf
CSRF_FAILURE_VIEW = 'carme.views.csrf_failure'
CSRF_TRUSTED_ORIGINS=['https://'+CARME_URL,'https://*.127.0.0.1']

## path
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
#-----------------------------------------------------------------------------------------------------------------------------------


# installed applications -----------------------------------------------------------------------------------------------------------
INSTALLED_APPS = [
    # default ---------------------    
    'django.contrib.admin',
    #'carme.apps.DbModelConfig',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # apps -------------------------
    'carme',
    'projects',
    # logs -------------------------
    #'django_db_logger',
    # others -----------------------
    #'sorl.thumbnail',
    'mathfilters',
    'misaka',
    #'dal',
    #'dal_select2', 
]
#-----------------------------------------------------------------------------------------------------------------------------------


# middlewares ----------------------------------------------------------------------------------------------------------------
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]
#-----------------------------------------------------------------------------------------------------------------------------------


# root url -------------------------------------------------------------------------------------------------------------------------
ROOT_URLCONF = 'scripts.urls'
#-----------------------------------------------------------------------------------------------------------------------------------


# templates -----------------------------------------------------------------------------------------------------------------
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [os.path.join(BASE_DIR, 'templates'), ],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                #'django_settings_export.settings_export',
            ],
        },
    },
]
#-----------------------------------------------------------------------------------------------------------------------------------


# wsgi app -----------------------------------------------------------------------------------------------------------------
WSGI_APPLICATION = 'scripts.wsgi.application'
#-----------------------------------------------------------------------------------------------------------------------------------


# Database -------------------------------------------------------------------------------------------------------------------------
# https://docs.djangoproject.com/en/4.2/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': CARME_DB_DEFAULT_ENGINE,
        'NAME': CARME_DB_DEFAULT_NAME,
        'USER': CARME_DB_DEFAULT_USER,
        'PASSWORD': CARME_PASSWORD_DJANGO,
        'HOST': CARME_DB_DEFAULT_HOST,
        'PORT': CARME_DB_DEFAULT_PORT,
    },

    'slurm': {
        'ENGINE': CARME_DB_SLURM_ENGINE,
        'NAME': CARME_DB_SLURM_NAME,
        'USER': CARME_DB_DEFAULT_USER,
        'PASSWORD': CARME_PASSWORD_DJANGO,
        'HOST': CARME_DB_SLURM_HOST,
        'PORT': CARME_DB_SLURM_PORT,
    },

}

DATABASE_ROUTERS = ('carme.dbrouters.MyDBRouter',)

DEFAULT_AUTO_FIELD = 'django.db.models.AutoField'
#-----------------------------------------------------------------------------------------------------------------------------------


# logging --------------------------------------------------------------------------------------------------------------------------
# https://docs.python.org/4.2/library/logging.html 

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '[{asctime}]: {levelname}: {module} {process:d} {thread:d} {message}',
            'style': '{',
            'datefmt': '%Y-%m-%d %H:%M:%S',
        },
        'simple': {
            'format': '[{asctime}]: {levelname}: {message}',
            'style': '{',
            'datefmt': '%Y-%m-%d %H:%M:%S',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/opt/Carme-Apache-Logs/django.log',
            'formatter': 'simple'
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': True,
        }
    }
}
#-----------------------------------------------------------------------------------------------------------------------------------

# internationalization -------------------------------------------------------------------------------------------------------------
# https://docs.djangoproject.com/en/4.2/topics/i18n/
LANGUAGE_CODE = 'en-us'
TIME_ZONE = CARME_TIMEZONE
USE_I18N = True
USE_L10N = True
USE_TZ = True
#-----------------------------------------------------------------------------------------------------------------------------------


# static files (CSS, JavaScript, Images) -------------------------------------------------------------------------------------------
# https://docs.djangoproject.com/en/4.2/howto/static-files/
SITE_ID = 1
STATIC_URL = '/static/'
STATIC_ROOT = '/opt/Carme/Carme-Frontend/Carme-Django/static/'
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')
#-----------------------------------------------------------------------------------------------------------------------------------
