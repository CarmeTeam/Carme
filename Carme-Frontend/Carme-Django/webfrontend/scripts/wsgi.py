"""
WSGI config for webfrontend project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/2.0/howto/deployment/wsgi/
"""

import os
from django.core.wsgi import get_wsgi_application
import time
import traceback
import signal
import sys

sys.path.append('/opt/Carme/Carme-Frontend/Carme-Django/webfrontend/')

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "scripts.settings")

application = get_wsgi_application()
