# Public IP for Django VM
resource "azurerm_public_ip" "django" {
  name                = "pip-django-${local.resource_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                = "Standard"
}

# Network interface for Django VM
resource "azurerm_network_interface" "django" {
  name                = "nic-django-${local.resource_suffix}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address           = local.django_instance_ips[0]
    public_ip_address_id         = azurerm_public_ip.django.id
  }
}

# Linux VM for Django application
resource "azurerm_linux_virtual_machine" "django" {
  name                = "vm-django-${local.resource_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  size                = "Standard_B1s"
  admin_username      = "azureadmin"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.django.id,
  ]

  admin_ssh_key {
    username   = "azureadmin"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# VM Extension for Django setup - Complete LDAP integration
# TEMPORARILY DISABLED: Managed identity permission issues
# Will use Docker-based deployment instead
/*
resource "azurerm_virtual_machine_extension" "django_setup" {
  name                       = "django-setup"
  virtual_machine_id         = azurerm_linux_virtual_machine.django.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = <<-EOF
      #!/bin/bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      
      # Logging function
      log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/django-setup.log
      }
      
      log "Starting Django setup with LDAP integration"
      
      # Update packages
      log "Updating packages..."
      apt-get update && apt-get upgrade -y
      apt-get install -y software-properties-common
      apt-get install -y python3 python3-pip python3-venv git nginx curl
      apt-get install -y libldap2-dev libsasl2-dev libssl-dev  # Required for python-ldap
      
      # Install Azure CLI
      log "Installing Azure CLI..."
      curl -sL https://aka.ms/InstallAzureCLIDeb | bash
      
      # Create django user if it doesn't exist - fix the user creation
      log "Creating django user..."
      if ! getent passwd django > /dev/null 2>&1; then
        useradd --system --shell /bin/bash --home /opt/django --create-home django
        log "Django user created successfully"
      else
        log "Django user already exists"
      fi
      
      # Setup Django application
      log "Setting up Django application..."
      mkdir -p /opt/django
      cd /opt/django
      
      # Clone or update repository
      if [ ! -d "app" ]; then
        log "Cloning repository..."
        git clone https://github.com/jamesrule4/Azure-412345.git app
      else
        log "Updating repository..."
        cd app && git pull && cd ..
      fi
      
      cd app/django_app
      
      # Create virtual environment if it doesn't exist
      log "Creating Python virtual environment..."
      if [ ! -d "venv" ]; then
        python3 -m venv venv
      fi
      
      # Activate virtual environment and install dependencies - use . instead of source for sh compatibility
      log "Installing Python dependencies..."
      . venv/bin/activate
      pip install --upgrade pip
      pip install -r requirements.txt gunicorn
      pip install django-auth-ldap python-ldap  # Install LDAP packages
      
      # Get LDAP bind password from Key Vault using managed identity
      log "Retrieving LDAP bind password from Key Vault..."
      # Wait for managed identity to be ready
      sleep 30
      
      # Login with managed identity
      az login --identity
      
      LDAP_BIND_PASSWORD=$(az keyvault secret show --vault-name ${azurerm_key_vault.main.name} --name ldap-bind-password-${terraform.workspace} --query value -o tsv)
      
      if [ -z "$LDAP_BIND_PASSWORD" ]; then
        log "ERROR: Failed to retrieve LDAP bind password"
        exit 1
      fi
      
      log "Successfully retrieved LDAP bind password"
      
      # Create environment file with all required variables
      log "Creating environment configuration..."
      cat > /opt/django/.env << EOL
DJANGO_SECRET_KEY=${random_password.django_admin.result}
DEBUG=False
ALLOWED_HOSTS=${local.django_instance_ips[0]},localhost,${azurerm_public_ip.django.ip_address}
LDAP_SERVER_URI=ldap://${local.domain_controller_ip}:389
LDAP_BIND_DN=CN=django,CN=Users,DC=rule4,DC=local
LDAP_BIND_PASSWORD=$LDAP_BIND_PASSWORD
RUNNING_IN_PRODUCTION=1
EOL
      
      # Django setup
      log "Running Django migrations and collecting static files..."
      python manage.py collectstatic --noinput
      python manage.py migrate
      
      # Create Django superuser and test LDAP connection
      log "Creating Django superuser and testing LDAP..."
      python manage.py shell << PYTHON_EOF
from django.contrib.auth.models import User
import os

# Create local Django superuser 'fox' with hardcoded password
if not User.objects.filter(username='fox').exists():
    User.objects.create_superuser('fox', 'fox@rule4.local', 'FoxAdmin2025!')
    print("Created Django superuser 'fox' with password 'FoxAdmin2025!'")
else:
    print("Django superuser 'fox' already exists")

# Test LDAP connection
try:
    import ldap
    from django_auth_ldap.config import LDAPSearch
    
    # Test basic LDAP connection
    ldap_uri = os.environ.get('LDAP_SERVER_URI')
    bind_dn = os.environ.get('LDAP_BIND_DN')
    bind_password = os.environ.get('LDAP_BIND_PASSWORD')
    
    print(f"Testing LDAP connection to {ldap_uri}")
    conn = ldap.initialize(ldap_uri)
    conn.simple_bind_s(bind_dn, bind_password)
    print("LDAP connection successful!")
    conn.unbind()
    
except Exception as e:
    print(f"LDAP connection test failed: {e}")
    print("Django will fall back to local authentication")

PYTHON_EOF
      
      # Set ownership
      log "Setting file permissions..."
      chown -R django:django /opt/django
      
      # Create systemd service
      log "Creating Django systemd service..."
      cat > /etc/systemd/system/django.service << EOL
[Unit]
Description=Django Gunicorn Application Server
After=network.target

[Service]
User=django
Group=django
WorkingDirectory=/opt/django/app/django_app
Environment="PATH=/opt/django/app/django_app/venv/bin"
EnvironmentFile=/opt/django/.env
ExecStart=/opt/django/app/django_app/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 config.wsgi:application
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL
      
      # Create nginx configuration
      log "Creating Nginx configuration..."
      cat > /etc/nginx/sites-available/django << EOL
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /static/ {
        alias /opt/django/app/django_app/static/;
    }
}
EOL
      
      # Enable and start services
      log "Enabling and starting services..."
      ln -sf /etc/nginx/sites-available/django /etc/nginx/sites-enabled/
      rm -f /etc/nginx/sites-enabled/default
      
      systemctl daemon-reload
      systemctl enable django
      systemctl start django
      systemctl enable nginx
      systemctl restart nginx
      
      # Wait for services to start
      log "Waiting for services to start..."
      sleep 10
      
      # Test Django application
      log "Testing Django application..."
      if curl -f http://localhost:8000/ > /dev/null 2>&1; then
        log "Django application is running successfully!"
      else
        log "WARNING: Django application may not be running properly"
        systemctl status django
      fi
      
      log "Django setup completed successfully!"
    EOF
  })

  depends_on = [
    azurerm_key_vault_secret.ldap_bind_password,
    azurerm_key_vault_secret.django_admin_password,
    azurerm_key_vault_secret.django_secret_key
  ]
}
*/

# Simple VM extension to install Docker and basic tools
resource "azurerm_virtual_machine_extension" "docker_setup" {
  name                       = "docker-setup"
  virtual_machine_id         = azurerm_linux_virtual_machine.django.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = <<-EOF
      #!/bin/bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      
      # Update packages
      apt-get update && apt-get upgrade -y
      
      # Install Docker
      curl -fsSL https://get.docker.com -o get-docker.sh
      sh get-docker.sh
      
      # Add azureadmin to docker group
      usermod -aG docker azureadmin
      
      # Install Docker Compose
      curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
      
      # Install Azure CLI for later use
      curl -sL https://aka.ms/InstallAzureCLIDeb | bash
      
      # Start Docker service
      systemctl start docker
      systemctl enable docker
      
      echo "Docker installation completed successfully!"
    EOF
  })
}

# Configure NSG rules for Django VMs - Fixed priorities to avoid conflicts
resource "azurerm_network_security_rule" "allow_rdp" {
  name                        = "AllowRDPFromRule4"
  priority                    = 105  # Changed from 100 to avoid conflict with AllowRDPToDC
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "allow_http" {
  name                        = "AllowHTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "allow_https" {
  name                        = "AllowHTTPS"
  priority                    = 125  # Changed from 120 to avoid conflict with AllowLDAPS
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "AllowSSH"
  priority                    = 130  # Changed from 115 to avoid conflict with AllowLDAP (115)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
} 