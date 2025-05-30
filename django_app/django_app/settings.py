import os
import ldap
from django_auth_ldap.config import LDAPSearch, GroupOfNamesType

# Base Django settings
SECRET_KEY = 'your-secret-key-here'  # TODO: Move to environment variable
DEBUG = False
ALLOWED_HOSTS = ['10.0.1.11']

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'django_app.urls'

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

WSGI_APPLICATION = 'django_app.wsgi.application'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
    }
}

# LDAP Authentication
AUTH_LDAP_SERVER_URI = "ldaps://10.0.1.10"
AUTH_LDAP_BIND_DN = "CN=fox,CN=Users,DC=rule4,DC=local"
AUTH_LDAP_BIND_PASSWORD = "Rule4SecureP0C2025!"  # TODO: Get from Key Vault

AUTH_LDAP_USER_SEARCH = LDAPSearch(
    "DC=rule4,DC=local",
    ldap.SCOPE_SUBTREE,
    "(sAMAccountName=%(user)s)",
)

AUTH_LDAP_GROUP_SEARCH = LDAPSearch(
    "DC=rule4,DC=local",
    ldap.SCOPE_SUBTREE,
    "(objectClass=group)",
)

AUTH_LDAP_GROUP_TYPE = GroupOfNamesType()

# User attributes
AUTH_LDAP_USER_ATTR_MAP = {
    "first_name": "givenName",
    "last_name": "sn",
    "email": "mail",
}

# Group mappings
AUTH_LDAP_USER_FLAGS_BY_GROUP = {
    "is_staff": "CN=DjangoStaff,CN=Users,DC=rule4,DC=local",
    "is_superuser": "CN=DjangoAdmins,CN=Users,DC=rule4,DC=local",
}

# Authentication backends
AUTHENTICATION_BACKENDS = [
    'django_auth_ldap.backend.LDAPBackend',
    'django.contrib.auth.backends.ModelBackend',
]

# Static files
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'static')

# Security settings
SECURE_SSL_REDIRECT = False  # Since we're behind Nginx
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
X_FRAME_OPTIONS = 'DENY' 