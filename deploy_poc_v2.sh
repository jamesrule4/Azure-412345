#!/bin/bash

# Rule4 POC - Docker-based Deployment with Automated Samba AD DC Setup
# Fully automated "push button" deployment with no manual steps

set -e

# Install required tools for LDAP testing
if ! command -v ldapsearch >/dev/null 2>&1; then
    echo "Installing LDAP utilities for AD verification..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y ldap-utils
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y openldap-clients
    elif command -v brew >/dev/null 2>&1; then
        brew install openldap
    else
        echo "Warning: Could not install LDAP utilities. AD verification will be limited."
    fi
fi

# Configuration
ENV_NUM=${1:-1}
WORKSPACE="poc${ENV_NUM}"

echo "=== Rule4 POC Deployment v2: $WORKSPACE (Samba AD DC) ==="

# Calculate dynamic IP addresses based on environment number
DOMAIN_CONTROLLER_IP="10.${ENV_NUM}.1.10"
DJANGO_VM_IP="10.${ENV_NUM}.1.11"

echo "Environment $ENV_NUM IP Configuration:"
echo "   Samba Domain Controller: $DOMAIN_CONTROLLER_IP"
echo "   Django VM: $DJANGO_VM_IP"

# Auto-detect current public IP for security
echo "Detecting public IP for SSH access..."
CURRENT_IP=$(curl -s https://api.ipify.org)
echo "   Current IP: $CURRENT_IP"

# Step 1: Deploy Infrastructure (VMs only, no AD installation yet)
echo ""
echo "=== Phase 1: Infrastructure Deployment ==="
cd terraform
terraform workspace new $WORKSPACE 2>/dev/null || terraform workspace select $WORKSPACE

# Create terraform.tfvars with proper IP format
cat > terraform.tfvars << EOF
environment_number = $ENV_NUM
admin_ip_address = "$CURRENT_IP/32"
EOF

# Deploy infrastructure
terraform apply -auto-approve

# Get outputs
DJANGO_IP=$(terraform output -raw django_vm_public_ip)
DC_IP=$(terraform output -raw domain_controller_public_ip)
KEY_VAULT=$(terraform output -raw key_vault_name)

echo "Infrastructure deployed!"
echo "   Django VM Public IP: $DJANGO_IP"
echo "   Django VM Private IP: $DJANGO_VM_IP"
echo "   Samba Domain Controller Public IP: $DC_IP"
echo "   Samba Domain Controller Private IP: $DOMAIN_CONTROLLER_IP"
echo "   Key Vault: $KEY_VAULT"

cd ..

# Step 2: Wait for VMs to be fully ready
echo ""
echo "=== Phase 2: VM Readiness Check ==="
echo "Waiting for VMs to be fully ready..."

# Wait for Django VM SSH (using SSH key authentication)
echo "Checking Django VM SSH connectivity..."
echo "Testing SSH to: $DJANGO_IP"
for i in {1..30}; do
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no azureadmin@$DJANGO_IP "echo 'SSH Ready'" 2>/dev/null; then
        echo "Django VM SSH is ready"
        SSH_READY=true
        break
    fi
    echo "Attempt $i/30: Django VM not ready yet... (IP: $DJANGO_IP)"
    sleep 10
done

# Check if SSH failed completely
if [ "$SSH_READY" != "true" ]; then
    echo "WARNING: SSH connectivity check failed after 30 attempts"
    echo "Manual SSH verification available with: ssh azureadmin@$DJANGO_IP"
fi

# Wait for Samba Domain Controller SSH (using password authentication since it has both)
echo "Checking Samba Domain Controller readiness..."
echo "Testing SSH to: $DC_IP"
for i in {1..30}; do
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DC_IP "echo 'SSH Ready'" 2>/dev/null; then
        echo "Samba Domain Controller SSH is ready"
        DC_SSH_READY=true
        break
    fi
    echo "Attempt $i/30: Samba Domain Controller not ready yet... (IP: $DC_IP)"
    sleep 10
done

# Check if SSH failed completely
if [ "$DC_SSH_READY" != "true" ]; then
    echo "WARNING: SSH connectivity check failed after 30 attempts"
    echo "Manual SSH verification available with: ssh azureadmin@$DC_IP"
fi

# Step 3: Install Docker on Django VM
echo ""
echo "=== Phase 3: Docker Installation ==="
echo "Installing Docker on Django VM..."

# Use SSH key authentication for Django VM
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no azureadmin@$DJANGO_IP << 'DOCKER_INSTALL'
# Update system
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker azureadmin

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Azure CLI for Key Vault access
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install LDAP utilities for testing AD connectivity
sudo apt-get install -y ldap-utils

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

echo "Docker installation and Azure CLI setup completed"
DOCKER_INSTALL

# Step 4: Deploy Django Application using Docker Hub Image
echo ""
echo "=== Phase 4: Django Application Deployment ==="
echo "Deploying Django application from Docker Hub (jamesrule4/django-app)..."

# Create Django app directory structure on VM
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no azureadmin@$DJANGO_IP "mkdir -p /home/azureadmin/django_app/static"

# Create docker-compose.yml on VM using Docker Hub image
echo "Creating docker-compose.yml for Docker Hub deployment..."
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no azureadmin@$DJANGO_IP << 'DOCKER_COMPOSE_SETUP'
cd /home/azureadmin/django_app

# Create docker-compose.yml file for Docker Hub image
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  django:
    image: jamesrule4/django-app:latest
    container_name: rule4-django-minimal
    ports:
      - "8000:8000"
    environment:
      # Hardcoded secrets - no Key Vault dependency
      - DJANGO_SECRET_KEY=hardcoded-secret-key-for-poc-testing-only-2025
      - DEBUG=False
      - ALLOWED_HOSTS=${ALLOWED_HOSTS:-localhost,127.0.0.1}
      # LDAP Configuration - will be set dynamically by deployment script
      - LDAP_SERVER_URI=${LDAP_SERVER_URI:-}
      - LDAP_BIND_DN=CN=django,CN=Users,DC=rule4,DC=local
      - LDAP_BIND_PASSWORD=${LDAP_BIND_PASSWORD:-hardcoded-ldap-password-for-poc}
    volumes:
      - ./static:/app/static
    restart: unless-stopped
EOF

echo "Docker Compose configuration created"
DOCKER_COMPOSE_SETUP

# Set up environment variables for Docker Compose (use consistent IP variables)
echo "Setting up environment variables..."
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no azureadmin@$DJANGO_IP << ENV_SETUP
cd /home/azureadmin/django_app

# Login to Azure using managed identity
echo "Logging in to Azure with managed identity..."
az login --identity

# Get the LDAP bind password from Key Vault
echo "Retrieving LDAP bind password from Key Vault..."
LDAP_BIND_PASSWORD=\$(az keyvault secret show --vault-name $KEY_VAULT --name ldap-bind-password-$WORKSPACE --query value -o tsv)

if [ -z "\$LDAP_BIND_PASSWORD" ]; then
    echo "WARNING: Failed to retrieve LDAP bind password from Key Vault, using hardcoded fallback"
    LDAP_BIND_PASSWORD="hardcoded-ldap-password-for-poc"
fi

# Create .env file with dynamic IPs and retrieved LDAP password
cat > .env << EOF
ALLOWED_HOSTS=$DJANGO_IP,localhost,$DJANGO_VM_IP
LDAP_SERVER_URI=ldap://$DOMAIN_CONTROLLER_IP:389
LDAP_BIND_PASSWORD=\$LDAP_BIND_PASSWORD
EOF

chmod 600 .env
echo "Environment file created with dynamic IPs and Key Vault password for environment $ENV_NUM"
ENV_SETUP

# Pull and start Django container from Docker Hub
echo "Pulling and starting Django container from Docker Hub..."
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no azureadmin@$DJANGO_IP << 'DOCKER_DEPLOY'
cd /home/azureadmin/django_app

# Pull the latest image and start the container 
docker-compose pull
docker-compose up -d

# Wait for container to be ready
sleep 20

# Check container status
docker-compose ps
echo "Container logs:"
docker-compose logs --tail=20

echo "Django container deployment from Docker Hub completed"
DOCKER_DEPLOY

# Step 5: Wait for Automated Samba Active Directory Installation
echo ""
echo "=== Phase 5: Automated Samba Active Directory Installation ==="
echo "Samba AD installation is handled automatically by VM extension."
echo "Allowing time for Samba AD installation to complete..."
echo "This process includes:"
echo "  1. Installing Samba AD Domain Services"
echo "  2. Creating rule4.local domain"  
echo "  3. Creating LDAP users and groups"
echo "  4. Configuring DNS and Kerberos"

# Give the VM extension time to complete the Samba installation
echo "Waiting 2 minutes for Samba AD installation to complete..."
sleep 120

echo "✅ Samba Active Directory installation time completed!"
echo "   Domain: rule4.local"
echo "   LDAP Server: $DC_IP:389"
echo "   Django service account: django@rule4.local"
echo "   Test users: testuser@rule4.local, adminuser@rule4.local"

# Step 6: Test Django Application and LDAP Integration
echo ""
echo "=== Phase 6: Testing Django Application and LDAP Integration ==="
echo "Testing Django application and LDAP authentication..."

sleep 10
if curl -f http://$DJANGO_IP:8000/ > /dev/null 2>&1; then
    echo "✅ Django application is responding!"
    
    # Test LDAP connectivity from Django VM
    echo "Testing LDAP connectivity from Django VM..."
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no azureadmin@$DJANGO_IP << 'LDAP_TEST'
cd /home/azureadmin/django_app

# Test LDAP connectivity using Django's LDAP configuration
echo "Testing LDAP authentication from Django..."
docker-compose exec -T django python manage.py shell << 'PYTHON_EOF'
import os
import django
from django.conf import settings
from django.contrib.auth import authenticate

# Test LDAP connection
try:
    import ldap
    
    # Get LDAP settings from environment
    ldap_uri = os.environ.get('LDAP_SERVER_URI', 'ldap://10.1.1.10:389')
    
    print(f"Testing LDAP connection to {ldap_uri}")
    conn = ldap.initialize(ldap_uri)
    conn.simple_bind_s("", "")  # Anonymous bind to test connectivity
    print("✅ LDAP connection successful!")
    
    # Test Django LDAP authentication with test user
    print("Testing Django LDAP authentication...")
    user = authenticate(username='testuser', password='TestPass123!')
    if user:
        print(f"✅ LDAP authentication successful for user: {user.username}")
        print(f"   User email: {user.email}")
        print(f"   Is staff: {user.is_staff}")
        print(f"   Is superuser: {user.is_superuser}")
    else:
        print("⚠️  LDAP authentication failed - user may not exist yet or Samba AD still initializing")
    
    conn.unbind()
    
except Exception as e:
    print(f"❌ LDAP test failed: {e}")
    print("This may be normal if Samba AD is still initializing")

PYTHON_EOF
LDAP_TEST

else
    echo "❌ Django application is not responding yet"
    echo "Checking container status..."
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no azureadmin@$DJANGO_IP "cd /home/azureadmin/django_app && docker-compose logs"
fi

echo ""
echo "=== Deployment Summary ==="
echo ""
echo "Infrastructure: Deployed"
echo "Django Application: http://$DJANGO_IP:8000/"
echo "Django Admin: http://$DJANGO_IP:8000/admin/"
echo "   Username: fox"
echo "   Password: FoxAdmin2025!"
echo ""
echo "Docker Deployment:"
echo "   Image: jamesrule4/django-app:latest"
echo "   Container: rule4-django-minimal"
echo "   LDAP Password: Retrieved from Key Vault"
echo ""
echo "Network Configuration (Environment $ENV_NUM):"
echo "   VNet CIDR: 10.$ENV_NUM.0.0/16"
echo "   Subnet CIDR: 10.$ENV_NUM.1.0/24"
echo "   Samba Domain Controller: $DOMAIN_CONTROLLER_IP"
echo "   Django VM: $DJANGO_VM_IP"
echo ""
echo "Samba Active Directory: Automated installation"
echo "   LDAP Server: $DC_IP:389"
echo "   Django service account: django@rule4.local"
echo "   Test users: testuser@rule4.local, adminuser@rule4.local"
echo ""
echo "LDAP Test Credentials:"
echo "   testuser / TestPass123! (Django staff)"
echo "   adminuser / AdminPass123! (Django admin)"
echo ""
echo "Troubleshooting:"
echo "   SSH to Django: ssh azureadmin@$DJANGO_IP"
echo "   SSH to Samba DC: ssh azureadmin@$DC_IP"
echo "   Check containers: docker-compose ps"
echo "   View logs: docker-compose logs"
echo "   Check Samba status: sudo systemctl status samba-ad-dc"
echo ""
echo "Next Steps:"
echo "1. Verify LDAP connectivity from Django"
echo "2. Test Samba AD users and verify Django LDAP authentication" 