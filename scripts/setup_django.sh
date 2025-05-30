#!/bin/bash

# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Install Python and dependencies
sudo apt-get install -y python3 python3-pip python3-venv python3-dev \
    build-essential libldap2-dev libsasl2-dev \
    nginx

# Create application directory
sudo mkdir -p /opt/django_app
cd /opt/django_app

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python packages
pip install -r requirements.txt

# Initialize Django project
django-admin startproject django_app .
python manage.py migrate
python manage.py collectstatic --noinput

# Configure Nginx
sudo tee /etc/nginx/sites-available/django <<EOF
server {
    listen 80;
    server_name _;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root /opt/django_app;
    }

    location / {
        proxy_pass http://unix:/run/gunicorn.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Enable the site
sudo ln -s /etc/nginx/sites-available/django /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Create systemd service for Gunicorn
sudo tee /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=Gunicorn daemon for Django application
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/django_app
ExecStart=/opt/django_app/venv/bin/gunicorn \
    --workers 3 \
    --bind unix:/run/gunicorn.sock \
    django_app.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
sudo chown -R www-data:www-data /opt/django_app
sudo chmod -R 755 /opt/django_app

# Start and enable services
sudo systemctl daemon-reload
sudo systemctl start gunicorn
sudo systemctl enable gunicorn
sudo systemctl restart nginx 