#!/bin/bash

# Update system and install dependencies
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv libldap2-dev libsasl2-dev

# Create project directory
sudo mkdir -p /opt/django_app
sudo chown -R azureuser:azureuser /opt/django_app

# Create and activate virtual environment
python3 -m venv /opt/django_app/venv
source /opt/django_app/venv/bin/activate

# Install Python packages
pip install django django-auth-ldap python-ldap

# Copy Django files
cp -r /home/azureuser/django_app/* /opt/django_app/

# Copy LDAP certificate
sudo mkdir -p /etc/ssl/certs
sudo cp /home/azureuser/ldaps.cer /etc/ssl/certs/

# Start Django development server
cd /opt/django_app
python manage.py migrate
python manage.py runserver 0.0.0.0:8000 