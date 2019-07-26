# ---------------------------------------------- 
# Carme
# ----------------------------------------------
# settings.py - central frontend settings                                                                                                                                                                    
#                                                                                                                                                                                                            
# see Carme development guide for documentation: 
# * Carme/Carme-Doc/DevelDoc/readme.md
#
# Copyright 2019 by Fraunhofer ITWM  
# License: http://open-carme.org/LICENSE.md 
# Contact: info@open-carme.org
# ---------------------------------------------   


import os
import ldap
import logging
from django_auth_ldap.config import LDAPSearch, GroupOfUniqueNamesType, PosixGroupType
from django.urls import reverse_lazy

#######################  
# Carme config
#######################               

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
import imp    
imp.load_source('CarmeConfig', BASE_DIR+'/../../CarmeConfig.frontend')
from CarmeConfig import *

LOAD_CUSTOM_SETTINGS=os.path.isfile(BASE_DIR+'/scripts/custom.py')

if LOAD_CUSTOM_SETTINGS:
    imp.load_source('custom', BASE_DIR+'/scripts/custom.py')
    from custom import custom_settings

#NOTE: use unified name some time
CARME_HEAD_NODE=CARME_HEADNODE_IP
CARME_LOGIN_NODE=CARME_LOGINNODE_IP
#######################


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/2.0/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = CARME_FRONTEND_KEY

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = CARME_FRONTEND_DEBUG

ALLOWED_HOSTS = [CARME_URL, CARME_LOGIN_NODE]

# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'carme-base.apps.DbModelConfig',
    'maintenance_mode',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.sites.apps.SitesConfig',
    'django.contrib.humanize.apps.HumanizeConfig',
    'django_nyt.apps.DjangoNytConfig',
    'django_db_logger',
    'chartjs',
    'mptt',
    'todo',
    'sekizai',
    'sorl.thumbnail',
    'wiki.apps.WikiConfig',
    'wiki.plugins.attachments.apps.AttachmentsConfig',
    'wiki.plugins.notifications.apps.NotificationsConfig',
    'wiki.plugins.images.apps.ImagesConfig',
    'wiki.plugins.macros.apps.MacrosConfig',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'maintenance_mode.middleware.MaintenanceModeMiddleware',
]

ROOT_URLCONF = 'scripts.urls'

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
                'maintenance_mode.context_processors.maintenance_mode',
                'sekizai.context_processors.sekizai',
                'django_settings_export.settings_export',
            ],
        },
    },
]

####################
#CARME CONFIG EXPORT
####################
SETTINGS_EXPORT = [
            'CARME_FRONTEND_LINK_PROXY',
            'CARME_FRONTEND_LINK_MONITOR',
            'CARME_FRONTEND_LINK_SWITCH',
            'CARME_FRONTEND_LINK_LDAP',
            'CARME_FRONTEND_LINK_MATTERMOST',
            'CARME_FRONTEND_LINK_DISCLAIMER',
            'CARME_FRONTEND_LINK_PRIVACY',
            'CARME_FRONTEND_LINK_ORGA_URL',
            'CARME_FRONTEND_LINK_ADMIN_CLUSTER_MONITOR',
            'CARME_FRONTEND_LOGO_TOP_LEFT',
            'CARME_FRONTEND_LOGO_TOP_RIGHT_1',
            'CARME_FRONTEND_LOGO_TOP_RIGHT_2',
            'CARME_FRONTEND_TITLE',
            'CARME_FRONTEND_DEBUG',

            ]


WSGI_APPLICATION = 'scripts.wsgi.application'


# Database
# https://docs.djangoproject.com/en/2.0/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'webfrontend',
        'USER': CARME_DB_USER,
        'PASSWORD': CARME_DB_PW,
        'HOST': CARME_DB_NODE,
        'PORT': CARME_DB_PORT,
    },

    'slurm': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'slurm_acct_db',
        'USER': CARME_DB_USER,
        'PASSWORD': CARME_DB_PW,
        'HOST': CARME_DB_NODE,
        'PORT': CARME_DB_PORT,
    },

}

DATABASE_ROUTERS = ('carme-base.dbrouters.MyDBRouter',)

# Password validation
# https://docs.djangoproject.com/en/2.0/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# -------------------------------------
# LOGGING
# https://docs.djangoproject.com/en/2.0/topics/logging/
# -------------------------------------

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '%(levelname)s %(asctime)s %(module)s %(process)d %(thread)d %(message)s'
        },
        'simple': {
            'format': '%(levelname)s %(asctime)s %(message)s'
        },
    },
    'handlers': {
        'db_log': {
            'level': 'DEBUG',
            'class': 'django_db_logger.db_log_handler.DatabaseLogHandler'
        },
    },
    'loggers': {
        'db': {
            'handlers': ['db_log'],
            'level': 'DEBUG'
        }
    }
}


# -------------------------------------
# LDAP
# -------------------------------------

LOGIN_URL = reverse_lazy('login')

AUTH_LDAP_SERVER_URI = "ldap://"+CARME_LDAP_SERVER_IP
AUTH_LDAP_BIND_DN = CARME_LDAP_BIND_DN
AUTH_LDAP_BIND_PASSWORD = CARME_LDAP_SERVER_PW


AUTH_LDAP_GROUP_SEARCH = LDAPSearch("dc={},dc={}".format(CARME_LDAP_DC1,CARME_LDAP_DC2),
                                    # GroupOfUniqueNames)"
                                    ldap.SCOPE_SUBTREE, "(objectClass=PosixGroup)"
                                    )

AUTH_LDAP_GROUP_TYPE = PosixGroupType()  # GroupOfUniqueNamesType()

AUTH_LDAP_USER_FLAGS_BY_GROUP = {
    "is_active": ("cn={},ou={},dc={},dc={}".format(CARME_LDAPGROUP_1,CARME_LDAPINSTANZ_1,CARME_LDAP_DC1,CARME_LDAP_DC2),
        "cn={},ou={},dc={},dc={}".format(CARME_LDAPGROUP_2,CARME_LDAPINSTANZ_2,CARME_LDAP_DC1,CARME_LDAP_DC2),
        "cn={},ou={},dc={},dc={}".format(CARME_LDAPGROUP_3,CARME_LDAPINSTANZ_3,CARME_LDAP_DC1,CARME_LDAP_DC2),
        "cn={},ou={},dc={},dc={}".format(CARME_LDAPGROUP_4,CARME_LDAPINSTANZ_4,CARME_LDAP_DC1,CARME_LDAP_DC2),
        "cn={},ou={},dc={},dc={}".format(CARME_LDAPGROUP_5,CARME_LDAPINSTANZ_5,CARME_LDAP_DC1,CARME_LDAP_DC2)),
    "is_staff": ("cn={},ou={},dc={},dc={}".format(CARME_LDAPGROUP_1,CARME_LDAPINSTANZ_1,CARME_LDAP_DC1,CARME_LDAP_DC2),),
    "is_superuser": ("cn={},ou={},dc={},dc={}".format(CARME_LDAPGROUP_1,CARME_LDAPINSTANZ_1,CARME_LDAP_DC1,CARME_LDAP_DC2))
}

AUTH_LDAP_MIRROR_GROUPS = True


AUTH_LDAP_USER_SEARCH = LDAPSearch("dc={},dc={}".format(CARME_LDAP_DC1,CARME_LDAP_DC2),
                                   ldap.SCOPE_SUBTREE, "(uid=%(user)s)")

AUTH_LDAP_USER_ATTR_MAP = {
    "first_name": "cn",
    "last_name": "cn",
    "email": "homeDirectory"
}

AUTHENTICATION_BACKENDS = [
    'django_auth_ldap.backend.LDAPBackend',
    'django.contrib.auth.backends.ModelBackend',
]

# Enable debug for ldap server connection
logger = logging.getLogger('django_auth_ldap')
logger.addHandler(logging.StreamHandler())
logger.setLevel(logging.DEBUG)

# ----------------------------------------

# Internationalization
# https://docs.djangoproject.com/en/2.0/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_L10N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/2.0/howto/static-files/

STATIC_URL = '/static/'
STATICFILES_DIRS = [
    os.path.join(BASE_DIR, "static"),
    CARME_ZABBIX_GRAPH_PATH,
]

STATIC_ROOT = CARME_FRONTEND_PATH+'/Carme-Django/static/'

#LOGIN_REDIRECT_URL = 'home'
LOGIN_REDIRECT_URL = '/'

# Wiki settings
WIKI_ACCOUNT_HANDLING = False
WIKI_ACCOUNT_SIGNUP_ALLOWED = False
SITE_ID = 1
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# maintanence mode
#MAINTENANCE_MODE = None
MAINTENANCE_MODE_IGNORE_SUPERUSER = True

# Auto logout
# SESSION_COOKIE_AGE = 60*60 # logout aufter one hour - regardless of activity
SESSION_EXPIRE_AT_BROWSER_CLOSE = True  # ende session after browser close
SESSION_AUTO_LOGOUT_TIME = 60*60  # logout aufter one hour od inactivity

# enable time zones
USE_TZ = True
TIME_ZONE = CARME_TIMEZONE

# Restrict access to ALL todo lists/views to `is_staff` users.
# If False or unset, all users can see all views (but more granular permissions are still enforced
# within views, such as requiring staff for adding and deleting lists).
TODO_STAFF_ONLY = False

# If you use the "public" ticket filing option, to whom should these tickets be assigned?
# Must be a valid username in your system. If unset, unassigned tickets go to "Anyone."
TODO_DEFAULT_ASSIGNEE = 'Team Carme'

# If you use the "public" ticket filing option, to which list should these tickets be saved?
# Defaults to first list found, which is probably not what you want!
TODO_DEFAULT_LIST_SLUG = 'tickets'

# If you use the "public" ticket filing option, to which *named URL* should the user be
# redirected after submitting? (since they can't see the rest of the ticket system).
# Defaults to "/"
TODO_PUBLIC_SUBMIT_REDIRECT = '/'

# additionnal classes the comment body should hold
# adding "text-monospace" makes comment monospace
TODO_COMMENT_CLASSES = ['class 1','class2']


if LOAD_CUSTOM_SETTINGS:
    custom_settings(globals())
