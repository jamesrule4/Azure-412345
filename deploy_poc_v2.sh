#!/bin/bash

# Rule4 POC - Docker-based Deployment with Automated LDAP/AD Setup
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

echo "=== Rule4 POC Deployment v2: $WORKSPACE ==="

# Calculate dynamic IP addresses based on environment number
DOMAIN_CONTROLLER_IP="10.${ENV_NUM}.1.10"
DJANGO_VM_IP="10.${ENV_NUM}.1.11"

echo "Environment $ENV_NUM IP Configuration:"
echo "   Domain Controller: $DOMAIN_CONTROLLER_IP"
echo "   Django VM: $DJANGO_VM_IP"

# Auto-detect current public IP for security
echo "Detecting your public IP for RDP access..."
CURRENT_IP=$(curl -s https://ipinfo.io/ip)
echo "   Your IP: $CURRENT_IP"

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
echo "   Domain Controller Public IP: $DC_IP"
echo "   Domain Controller Private IP: $DOMAIN_CONTROLLER_IP"
echo "   Key Vault: $KEY_VAULT"

cd ..

# Step 2: Wait for VMs to be fully ready
echo ""
echo "=== Phase 2: VM Readiness Check ==="
echo "Waiting for VMs to be fully ready..."

# Wait for Django VM SSH (using password auth, not SSH keys)
echo "Checking Django VM SSH connectivity..."
echo "Testing SSH to: $DJANGO_IP"
for i in {1..30}; do
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP "echo 'SSH Ready'" 2>/dev/null; then
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
    echo "Attempting to continue deployment - VM may still be initializing"
    echo "You can manually verify SSH with: ssh azureadmin@$DJANGO_IP"
fi

# Wait for Domain Controller RDP/WinRM
echo "Checking Domain Controller readiness..."
echo "Testing RDP to: $DC_IP"
for i in {1..30}; do
    if nc -z $DC_IP 3389 2>/dev/null; then
        echo "Domain Controller RDP is ready"
        RDP_READY=true
        break
    fi
    echo "Attempt $i/30: Domain Controller not ready yet... (IP: $DC_IP)"
    sleep 10
done

# Check if RDP failed completely
if [ "$RDP_READY" != "true" ]; then
    echo "WARNING: RDP connectivity check failed after 30 attempts"
    echo "Attempting to continue deployment - VM may still be initializing"
    echo "You can manually verify RDP to: $DC_IP"
fi

# Step 3: Install Docker on Django VM
echo ""
echo "=== Phase 3: Docker Installation ==="
echo "Installing Docker on Django VM..."

# Use consistent IP variable and remove SSH key reference
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP << 'DOCKER_INSTALL'
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

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

echo "Docker installation completed"
DOCKER_INSTALL

# Step 4: Deploy Django Application using Docker
echo ""
echo "=== Phase 4: Django Application Deployment ==="
echo "Deploying Django application from Docker Hub..."

# Create Django app directory structure on VM for docker-compose
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP "mkdir -p /home/azureadmin/django_app"

# Copy only the docker-compose.yml file to VM
echo "Copying Docker Compose configuration..."
scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes django_app/docker-compose.yml azureadmin@$DJANGO_IP:/home/azureadmin/django_app/

# Set up environment variables for Docker Compose
echo "Setting up environment variables..."
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP << ENV_SETUP
cd /home/azureadmin/django_app

# Create .env file with dynamic IPs and environment variables
cat > .env << EOF
ALLOWED_HOSTS=$DJANGO_IP,localhost,$DJANGO_VM_IP
LDAP_SERVER_URI=ldap://$DOMAIN_CONTROLLER_IP:389
DJANGO_SECRET_KEY=hardcoded-secret-key-for-poc-testing-only-2025
DEBUG=False
EOF

chmod 600 .env
echo "Environment file created with dynamic IPs for environment $ENV_NUM"
ENV_SETUP

# Pull and start Django container from Docker Hub
echo "Pulling latest Django image from Docker Hub and starting container..."
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP << 'DOCKER_DEPLOY'
cd /home/azureadmin/django_app

# Pull the latest image from Docker Hub
echo "Pulling latest Django image from Docker Hub..."
docker pull jamesrule4/django-app:latest

# Start the container using docker-compose
echo "Starting Django container..."
docker-compose up -d

# Wait for container to be ready
echo "Waiting for container to start..."
sleep 15

# Check container status
echo "Container status:"
docker-compose ps

echo "Container logs:"
docker-compose logs --tail=20

echo "Django container deployment completed"
DOCKER_DEPLOY

# Step 5: Wait for Automated Active Directory Installation
echo ""
echo "=== Phase 5: Automated Active Directory Installation ==="
echo "Waiting for automated AD installation to complete..."
echo "This process includes:"
echo "  1. Installing AD Domain Services"
echo "  2. Creating rule4.local domain"
echo "  3. Automatic reboot"
echo "  4. Creating LDAP users and groups"

# Use hardcoded admin password (consistent with Terraform)
DC_PASSWORD="TempAdminPass2025!"

# Wait for AD installation to complete (VM extension handles this automatically)
echo "Monitoring AD installation progress..."
AD_READY=false
for i in {1..60}; do
    echo "Checking AD installation progress... (attempt $i/60)"
    
    # Check if we can connect to LDAP port (indicates AD is running)
    if timeout 10 bash -c "</dev/tcp/$DC_IP/389" 2>/dev/null; then
        echo "LDAP port 389 is responding on Domain Controller"
        
        # Additional check: try to query AD using ldapsearch if available
        # This is a more reliable indicator that AD is fully configured
        if command -v ldapsearch >/dev/null 2>&1; then
            if ldapsearch -x -H "ldap://$DC_IP:389" -b "DC=rule4,DC=local" "(objectClass=domain)" dn 2>/dev/null | grep -q "rule4.local"; then
                echo "Active Directory domain rule4.local is responding!"
                AD_READY=true
                break
            fi
        else
            # If ldapsearch not available, assume AD is ready if port is open
            echo "LDAP port is open, assuming AD installation completed"
            AD_READY=true
            break
        fi
    fi
    
    echo "AD installation still in progress... waiting 30 seconds"
    sleep 30
done

if [ "$AD_READY" = "true" ]; then
    echo "✅ Active Directory installation completed successfully!"
    echo "   Domain: rule4.local"
    echo "   LDAP Server: $DC_IP:389"
    echo "   Django service account: django@rule4.local"
    echo "   Test users: testuser@rule4.local, adminuser@rule4.local"
else
    echo "⚠️  AD installation is taking longer than expected"
    echo "   The VM extension may still be running in the background"
    echo "   You can check progress by RDPing to: $DC_IP"
    echo "   Username: azureadmin"
    echo "   Password: $DC_PASSWORD"
fi

# Step 6: Test Django Application and LDAP Integration
echo ""
echo "=== Phase 6: Testing Django Application and LDAP Integration ==="
echo "Testing Django application and LDAP authentication..."

sleep 10
if curl -f http://$DJANGO_IP:8000/ > /dev/null 2>&1; then
    echo "✅ Django application is responding!"
    
    # Test LDAP connectivity from Django VM
    echo "Testing LDAP connectivity from Django VM..."
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP << 'LDAP_TEST'
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
        print("⚠️  LDAP authentication failed - user may not exist yet or AD still initializing")
    
    conn.unbind()
    
except Exception as e:
    print(f"❌ LDAP test failed: {e}")
    print("This may be normal if AD is still initializing")

PYTHON_EOF
LDAP_TEST

else
    echo "❌ Django application is not responding yet"
    echo "Checking container status..."
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP "cd /home/azureadmin/django_app && docker-compose logs"
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
echo "Network Configuration (Environment $ENV_NUM):"
echo "   VNet CIDR: 10.$ENV_NUM.0.0/16"
echo "   Subnet CIDR: 10.$ENV_NUM.1.0/24"
echo "   Domain Controller: $DOMAIN_CONTROLLER_IP"
echo "   Django VM: $DJANGO_VM_IP"
echo ""
echo "Active Directory: Automated installation"
echo "   LDAP Server: $DC_IP:389"
echo "   Django service account: django@rule4.local"
echo "   Test users: testuser@rule4.local, adminuser@rule4.local"
echo ""
echo "Troubleshooting:"
echo "   SSH to Django: ssh azureadmin@$DJANGO_IP"
echo "   Check containers: docker-compose ps"
echo "   View logs: docker-compose logs"
echo ""
echo "Next Steps:"
echo "1. Verify LDAP connectivity from Django"
echo "2. Create test users in AD and verify Django LDAP authentication" 