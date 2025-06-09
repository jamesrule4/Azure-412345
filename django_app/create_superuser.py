#!/usr/bin/env python3
"""
Django Superuser Creation Script
Creates the 'fox' superuser with password from Key Vault
"""

import os
import sys
import django
from django.contrib.auth import get_user_model

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'django_app.settings')
django.setup()

def create_fox_user():
    """Create the fox superuser"""
    User = get_user_model()
    fox_password = 'FoxAdmin2025!'  # Hardcoded Django admin password
    
    try:
        # Check if user already exists
        if User.objects.filter(username='fox').exists():
            print("User 'fox' already exists")
            return True
        
        # Create superuser
        user = User.objects.create_superuser(
            username='fox',
            email='fox@rule4.local',
            password=fox_password,
            first_name='Fox',
            last_name='Admin'
        )
        
        print("Created Django superuser 'fox'")
        print(f"   Username: fox")
        print(f"   Password: {fox_password}")
        
        return True
        
    except Exception as e:
        print(f"Error creating fox user: {e}")
        return False

if __name__ == "__main__":
    if create_fox_user():
        print("Fox superuser setup completed!")
        sys.exit(0)
    else:
        print("Fox superuser setup failed!")
        sys.exit(1) 