#!/usr/bin/env python3
"""
Initialize Django application with database migrations and superuser creation.
This script is run during Docker container startup.
"""

import os
import sys
import django
from django.core.management import execute_from_command_line

# Set Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# Setup Django
django.setup()

def main():
    """Initialize Django application"""
    print("Initializing Django application...")
    
    # Run migrations
    print("Running database migrations...")
    execute_from_command_line(['manage.py', 'migrate', '--noinput'])
    
    # Create superuser if it doesn't exist
    print("Creating superuser...")
    execute_from_command_line(['manage.py', 'shell', '-c', """
from django.contrib.auth.models import User
if not User.objects.filter(username='fox').exists():
    User.objects.create_superuser('fox', 'fox@rule4.local', 'FoxAdmin2025!')
    print('Superuser created: fox')
else:
    print('Superuser already exists: fox')
"""])
    
    print("Django initialization completed!")

if __name__ == '__main__':
    main() 