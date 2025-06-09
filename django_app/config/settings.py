"""
Django settings for Rule4 POC project.
This module contains all Django and LDAP authentication settings.
The settings are designed to work with Azure Key Vault for secret management.
"""

import os
from pathlib import Path
import ldap
from django_auth_ldap.config import LDAPSearch, GroupOfNamesType, ActiveDirectoryGroupType
from dotenv import load_dotenv

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# Load environment variables from .env file
load_dotenv(os.path.join(BASE_DIR, '.env'))

# Base Django settings - Retrieved from Key Vault in production
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'dev-only-local-key')
DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'

# Parse ALLOWED_HOSTS from environment
allowed_hosts_str = os.environ.get('ALLOWED_HOSTS', 'localhost')
ALLOWED_HOSTS = [host.strip() for host in allowed_hosts_str.split(',')]

# Application definition - Standard Django apps
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'authentication',  # Custom authentication app
]

# Standard Django middleware for security and session management
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

# Template configuration with default Django backend
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [os.path.join(BASE_DIR, 'templates')],
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

# Database configuration - Using SQLite for simplicity
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
    }
}

# LDAP Authentication settings
# All sensitive values are retrieved from Azure Key Vault in production
AUTH_LDAP_SERVER_URI = os.environ.get('LDAP_SERVER_URI', 'ldap://localhost')  # Will be set by Terraform
AUTH_LDAP_BIND_DN = os.environ.get('LDAP_BIND_DN', 'CN=django,CN=Users,DC=rule4,DC=local')
AUTH_LDAP_BIND_PASSWORD = os.environ.get('LDAP_BIND_PASSWORD', '')  # Retrieved from Key Vault

# LDAP user search configuration
AUTH_LDAP_USER_SEARCH = LDAPSearch(
    "DC=rule4,DC=local",  # Base DN for user search
    ldap.SCOPE_SUBTREE,   # Search entire subtree
    "(sAMAccountName=%(user)s)",  # Filter by Windows username
)

# LDAP group search configuration
AUTH_LDAP_GROUP_SEARCH = LDAPSearch(
    "DC=rule4,DC=local",
    ldap.SCOPE_SUBTREE,
    "(objectClass=group)",
)

AUTH_LDAP_GROUP_TYPE = GroupOfNamesType()

# Map LDAP attributes to Django user attributes
AUTH_LDAP_USER_ATTR_MAP = {
    "first_name": "givenName",
    "last_name": "sn",
    "email": "mail",
}

# Map LDAP groups to Django permissions
AUTH_LDAP_USER_FLAGS_BY_GROUP = {
    "is_staff": "CN=DjangoStaff,CN=Users,DC=rule4,DC=local",
    "is_superuser": "CN=DjangoAdmins,CN=Users,DC=rule4,DC=local",
}

# Authentication backend configuration
# LDAP is primary, with Django model backend as fallback
AUTHENTICATION_BACKENDS = [
    'django_auth_ldap.backend.LDAPBackend',
    'django.contrib.auth.backends.ModelBackend',
]

# Static files configuration
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'static')

# Security settings
SECURE_SSL_REDIRECT = False  # SSL termination happens at Nginx
SESSION_COOKIE_SECURE = False  # Set to True when using HTTPS
CSRF_COOKIE_SECURE = False    # Set to True when using HTTPS
X_FRAME_OPTIONS = 'DENY'  # Prevent clickjacking

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Login settings
LOGIN_URL = '/admin/login/'
LOGIN_REDIRECT_URL = '/admin/'
LOGOUT_REDIRECT_URL = '/admin/login/'

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