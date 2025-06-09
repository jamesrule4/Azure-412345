#!/bin/bash

# Rule4 POC - Docker-based Deployment with Proper Sequencing
# Addresses timing issues and uses containerized Django

set -e

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
echo "Deploying Django application with Docker..."

# Create Django app directory structure on VM
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP "mkdir -p /home/azureadmin/django_app"

# Copy Django files to VM (remove SSH key reference)
echo "Copying Django application files..."
scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes -r django_app/* azureadmin@$DJANGO_IP:/home/azureadmin/django_app/

# Set up environment variables for Docker Compose (use consistent IP variables)
echo "Setting up environment variables..."
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP << ENV_SETUP
cd /home/azureadmin/django_app

# Create .env file with dynamic IPs and hardcoded secrets
cat > .env << EOF
ALLOWED_HOSTS=$DJANGO_IP,localhost,$DJANGO_VM_IP
LDAP_SERVER_URI=ldap://$DOMAIN_CONTROLLER_IP:389
EOF

chmod 600 .env
echo "Environment file created with dynamic IPs for environment $ENV_NUM"
ENV_SETUP

# Build and start Django container
echo "Building and starting Django container..."
ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP << 'DOCKER_DEPLOY'
cd /home/azureadmin/django_app

# Initialize Django (run migrations and create superuser)
echo "Initializing Django..."
python3 init_django.py || echo "Django initialization failed - will try in container"

# Build and start the container 
docker-compose up -d --build

# Wait for container to be ready
sleep 15

# Check container status
docker-compose ps
echo "Container logs:"
docker-compose logs --tail=20

echo "Django container deployment completed"
DOCKER_DEPLOY

# Step 5: Install Active Directory (Now that everything is ready)
echo ""
echo "=== Phase 5: Active Directory Installation ==="
echo "Installing Active Directory on Domain Controller..."

# Use hardcoded admin password (no Key Vault dependency)
DC_PASSWORD="TempAdminPass2025!"

# Create AD installation script
cat > /tmp/install_ad.ps1 << 'AD_SCRIPT'
# Install AD Domain Services
Write-Output "Installing AD Domain Services..."
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Install the domain
Write-Output "Creating rule4.local domain..."
Import-Module ADDSDeployment
$SafeModePassword = ConvertTo-SecureString 'ADMIN_PASSWORD_PLACEHOLDER' -AsPlainText -Force
Install-ADDSForest -DomainName rule4.local -SafeModeAdministratorPassword $SafeModePassword -Force -NoRebootOnCompletion:$false

Write-Output "Domain installation initiated. System will reboot."
AD_SCRIPT

# Replace password placeholder
sed -i "s/ADMIN_PASSWORD_PLACEHOLDER/$DC_PASSWORD/g" /tmp/install_ad.ps1

# Copy and execute AD installation script on Domain Controller
# Note: This requires WinRM to be enabled, which should happen automatically
echo "Executing AD installation script..."
echo "Note: Domain Controller will reboot during this process"

# For now, we'll provide manual instructions since WinRM setup is complex
echo ""
echo "=== Manual AD Installation Required ==="
echo "Please RDP to the Domain Controller and run the following PowerShell scripts:"
echo ""
echo "Domain Controller: $DC_IP"
echo "Username: azureadmin"
echo "Password: $DC_PASSWORD"
echo ""
echo "Step 1 - Install Active Directory (run this first):"
cat /tmp/install_ad.ps1
echo ""
echo "Step 2 - After reboot, create LDAP users (run this after AD installation):"
echo "# Create LDAP test users"
echo "New-ADUser -Name 'testuser' -UserPrincipalName 'testuser@rule4.local' -AccountPassword (ConvertTo-SecureString 'TestPass123!' -AsPlainText -Force) -Enabled \$true"
echo "New-ADUser -Name 'django' -UserPrincipalName 'django@rule4.local' -AccountPassword (ConvertTo-SecureString 'hardcoded-ldap-password-for-poc' -AsPlainText -Force) -Enabled \$true"
echo ""

# Step 6: Test Django Application
echo ""
echo "=== Phase 6: Testing Django Application ==="
echo "Testing Django application..."

sleep 10
if curl -f http://$DJANGO_IP:8000/ > /dev/null 2>&1; then
    echo "Django application is responding!"
else
    echo "Django application is not responding yet"
    echo "Checking container status..."
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes azureadmin@$DJANGO_IP "cd /home/azureadmin/django_app && docker-compose logs"
fi

# Cleanup
rm -f /tmp/install_ad.ps1

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
echo "Active Directory: Manual installation required"
echo "   RDP to: $DC_IP"
echo "   Username: azureadmin"
echo "   Password: $DC_PASSWORD"
echo ""
echo "Troubleshooting:"
echo "   SSH to Django: ssh azureadmin@$DJANGO_IP"
echo "   Check containers: docker-compose ps"
echo "   View logs: docker-compose logs"
echo ""
echo "Next Steps:"
echo "1. RDP to Domain Controller and install AD using the provided script"
echo "2. After AD installation, test LDAP connectivity from Django"
echo "3. Create test users in AD and verify Django LDAP authentication" 