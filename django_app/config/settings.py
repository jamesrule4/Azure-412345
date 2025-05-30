"""
Django settings for the project.
"""

import os
import ldap
from pathlib import Path
from dotenv import load_dotenv
from django_auth_ldap.config import LDAPSearch, GroupOfNamesType

# Load environment variables
load_dotenv()

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'django-insecure-default-key-change-me')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.getenv('DJANGO_DEBUG', 'True').lower() == 'true'

ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'authentication',
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
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# Logging configuration
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'level': 'DEBUG',
        },
    },
    'loggers': {
        'django_auth_ldap': {
            'level': 'DEBUG',
            'handlers': ['console'],
        },
    }
}

# LDAP Authentication
AUTH_LDAP_SERVER_URI = f"ldaps://{os.getenv('DC_IP', '10.0.1.10')}"

# TLS Settings for LDAPS
AUTH_LDAP_START_TLS = False  # Not needed with LDAPS
AUTH_LDAP_GLOBAL_OPTIONS = {
    ldap.OPT_X_TLS_REQUIRE_CERT: ldap.OPT_X_TLS_NEVER,
    ldap.OPT_REFERRALS: 0,  # Required for Windows AD
    ldap.OPT_PROTOCOL_VERSION: 3,  # Use LDAP v3
    ldap.OPT_X_TLS_NEWCTX: 0,  # Required for TLS
    ldap.OPT_TIMEOUT: 30,  # Connection timeout in seconds
    ldap.OPT_NETWORK_TIMEOUT: 10,  # Network timeout in seconds
}

# The following DN will be used to bind to the LDAP server
AUTH_LDAP_BIND_DN = "CN=Administrator,CN=Users,DC=internal,DC=domain"
AUTH_LDAP_BIND_PASSWORD = os.getenv('LDAP_BIND_PASSWORD', '')

# User search
AUTH_LDAP_USER_SEARCH = LDAPSearch(
    "CN=Users,DC=internal,DC=domain",
    ldap.SCOPE_SUBTREE,
    "(sAMAccountName=%(user)s)"
)

# Group search
AUTH_LDAP_GROUP_SEARCH = LDAPSearch(
    "CN=Users,DC=internal,DC=domain",
    ldap.SCOPE_SUBTREE,
    "(objectClass=group)"
)

# Group type
AUTH_LDAP_GROUP_TYPE = GroupOfNamesType()

# User attributes
AUTH_LDAP_USER_ATTR_MAP = {
    'first_name': 'givenName',
    'last_name': 'sn',
    'email': 'mail',
}

# Group attributes
AUTH_LDAP_USER_FLAGS_BY_GROUP = {
    "is_staff": "CN=DjangoStaff,CN=Users,DC=internal,DC=domain",
    "is_superuser": "CN=DjangoAdmins,CN=Users,DC=internal,DC=domain"
}

# Cache settings
AUTH_LDAP_CACHE_GROUPS = True
AUTH_LDAP_GROUP_CACHE_TIMEOUT = 300  # 5 minutes

# Authentication backends
AUTHENTICATION_BACKENDS = [
    'django_auth_ldap.backend.LDAPBackend',
    'django.contrib.auth.backends.ModelBackend',
]

# Password validation
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

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# Static files
STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Login settings
LOGIN_URL = 'login'
LOGIN_REDIRECT_URL = 'home' 