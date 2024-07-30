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
#import ldap
#from django_auth_ldap.config import LDAPSearch, PosixGroupType, LDAPGroupQuery, GroupOfNamesType
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
    #'django_otp.plugins.otp_static',
    #'django_otp.plugins.otp_totp',
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

"""
# Login ----------------------------------------------------------------------------------------------------------------------------
LOGIN_URL = 'two_factor:login'
LOGIN_REDIRECT_URL = '/'
LOGOUT_REDIRECT_URL = 'account/login/'
#----------------------------------------------------------------------------------------------------------------------------------


# LDAP -----------------------------------------------------------------------------------------------------------------------------
# NOTE: This section has to be modified according to your specific LDAP setup!
#       In particualar the variables
#         - AUTH_LDAP_GROUP_BASE
#         - AUTH_LDAP_USER_BASE
#         - AUTH_LDAP_GROUP_FILTER
#         - AUTH_LDAP_USER_SEARCH or AUTH_LDAP_USER_DN_TEMPLATE
#         - AUTH_LDAP_GROUP_TYPE
#         - AUTH_LDAP_REQUIRE_GROUP (if you want to limit access)
#         - AUTH_LDAP_USER_FLAGS_BY_GROUP
#         - AUTH_LDAP_USER_ATTR_MAP
#       have to be checked and (maybe) adjusted.
#       This has to be done as django is at this point in thime not able to be so generic to work with every possible LDAP setup.


# set ldap server uri
AUTH_LDAP_SERVER_URI = CARME_LDAP_SERVER_PROTO + CARME_LDAP_SERVER_IP


# set ldap bind dn
AUTH_LDAP_BIND_DN = CARME_LDAP_BIND_DN


# set ldap password
AUTH_LDAP_BIND_PASSWORD = CARME_LDAP_SERVER_PW


# define ldap base dn
LDAP_BASE_DN = CARME_LDAP_BASE_DN


# set ldap base dn to search for groups
# NOTE: This is an example!
AUTH_LDAP_GROUP_BASE = LDAP_BASE_DN
#AUTH_LDAP_GROUP_BASE = "cn=groups," + LDAP_BASE_DN                                       # example how to modify this variable


# set ldap base dn to search for users
# NOTE: This is an example!
AUTH_LDAP_USER_BASE = LDAP_BASE_DN
#AUTH_LDAP_USER_BASE = 'cn=users,' + LDAP_BASE_DN                                         # example how to modify this variable


# define ldap group filter
# NOTE: This is an example!
AUTH_LDAP_GROUP_FILTER = "(objectClass=PosixGroup)"
#AUTH_LDAP_GROUP_FILTER = "(&(objectClass=groupOfNames)(|(cn=admins)(cn=users)))"         # example of anohter search filter


# format authenticating users distinguished name
# using ldap user search
AUTH_LDAP_USER_SEARCH = LDAPSearch(AUTH_LDAP_USER_BASE,
                                   ldap.SCOPE_SUBTREE, "(uid=%(user)s)")
# using user dn template
#AUTH_LDAP_USER_DN_TEMPLATE = 'uid=%(user)s,' + AUTH_LDAP_USER_BASE


# format authenticating groups distinguished name using ldap user search
AUTH_LDAP_GROUP_SEARCH = LDAPSearch(AUTH_LDAP_GROUP_BASE,
                                    ldap.SCOPE_SUBTREE, AUTH_LDAP_GROUP_FILTER
                                    )


# define ldap group type
# NOTE: This is an example!
AUTH_LDAP_GROUP_TYPE = PosixGroupType()
#AUTH_LDAP_GROUP_TYPE = GroupOfNamesType(name_attr="cn")                                  # example of another group type


# restricts groups that are allowed to user CARME
# NOTE: If you don't want to restrict the access to specific LDAP groups simply comment the AUTH_LDAP_REQUIRE_GROUP variable
# NOTE: This is an example!
AUTH_LDAP_REQUIRE_GROUP = (LDAPGroupQuery('cn=admins,' + AUTH_LDAP_GROUP_BASE)
                           | LDAPGroupQuery('cn=users,' + AUTH_LDAP_GROUP_BASE)
                          )


# set user flags by ldap groups
# NOTE: If you cannot modify AUTH_LDAP_GROUP_BASE in such a way that it maps all your possible groups modify it directly
# NOTE: there is no limitation regarding the goups you can add here
# NOTE: This is an example!
AUTH_LDAP_USER_FLAGS_BY_GROUP = {
    'is_active': (
        LDAPGroupQuery('cn=admins,' + AUTH_LDAP_GROUP_BASE)
        | LDAPGroupQuery('cn=users,' + AUTH_LDAP_GROUP_BASE)
    ),
    'is_staff': 'cn=admins,' + AUTH_LDAP_GROUP_BASE,
    'is_superuser': 'cn=admins,' + AUTH_LDAP_GROUP_BASE,
}


# mirror a user’s ldap group membership
AUTH_LDAP_MIRROR_GROUPS = True


# populate the django user from the LDAP directory
# NOTE: This is an example!
AUTH_LDAP_USER_ATTR_MAP = {
    "first_name": "cn",
    "last_name": "cn",
    "email": "homeDirectory",
    #"full_name": "displayName",
}


# set authentication backends
AUTHENTICATION_BACKENDS = [
    'django_auth_ldap.backend.LDAPBackend',
    'django.contrib.auth.backends.ModelBackend',
]


# enable debug for ldap server connection
logger = logging.getLogger('django_auth_ldap')
logger.addHandler(logging.StreamHandler())
logger.setLevel(logging.DEBUG)
# ----------------------------------------------------------------------------------------------------------------------------------
"""
