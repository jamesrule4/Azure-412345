# Azure Active Directory Integration POC

This project demonstrates automated deployment of isolated Windows Active Directory domains with Django web applications in Azure using Docker containerization. Each deployment creates a self-contained environment that can scale to thousands of identical environments.

## Current Status

**Infrastructure**: Deployed and operational
- **Django VM**: Ubuntu 22.04 with Docker
- **Domain Controller**: Windows Server 2022 
- **Key Vault**: Automated secret management
- **Network**: Isolated VNet with dynamic IP addressing

**Django Application**: Docker-based deployment
- Infrastructure deployed successfully
- Docker installed and configured
- Django container deployment automated
- Manual verification/completion may be needed

**Active Directory**: Manual installation required
- Infrastructure ready, manual AD setup needed via RDP

## Quick Start

Deploy a new environment with Docker-based Django:

```bash
./deploy_poc_v2.sh [environment_number]  # Deploy POC environment
```

The script automatically:
- **Phase 1**: Deploys infrastructure (VMs, networking, Key Vault)
- **Phase 2**: Waits for VMs to be ready with connectivity checks
- **Phase 3**: Installs Docker and Docker Compose on Django VM
- **Phase 4**: Deploys Django application using Docker containers
- **Phase 5**: Provides manual AD installation instructions
- **Phase 6**: Tests Django application accessibility

## What Gets Created

Each environment includes:
- **Windows Domain Controller** (manual AD setup required)
- **Django Application Server** running in Docker containers
- **Virtual Network** with isolated IP ranges (10.X.0.0/16)
- **Azure Key Vault** for secret management
- **Network Security Groups** with proper access controls
- **Docker-based Django deployment** with LDAP authentication capability

## Environment Isolation

Each environment is completely isolated:
- **Workspace**: poc1, poc2, poc3, poc4, etc.
- **Network**: 10.1.0.0/16, 10.2.0.0/16, 10.3.0.0/16, etc.
- **Resources**: All resources have unique names with environment suffix
- **State**: Separate Terraform state files for each environment
- **Dynamic IPs**: Automatically calculated based on environment number

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Azure VNet (10.X.0.0/16)                     │
│   ┌──────────────────────────┐      ┌───────────────────────┐   │
│   │    Domain Controller     │      │     Django Server     │   │
│   │    Windows Server 2022   │      │     Ubuntu 22.04      │   │
│   │    10.X.1.10            │      │     10.X.1.11         │   │
│   │    - Active Directory    │◄────►│     - Docker Engine   │   │
│   │    - DNS Server         │      │     - Django Container│   │
│   │    (Manual Setup)       │      │     - LDAP Client     │   │
│   └──────────────────────────┘      └───────────────────────┘   │
│                    ▲                           ▲                 │
│                    │                           │                 │
│                    └───────────────┬───────────┘                 │
│                                    │                             │
│                            ┌───────▼──────┐                      │
│                            │  Key Vault   │                      │
│                            └─────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

## Docker-Based Django Deployment

The Django application runs in Docker containers for better consistency and portability:

### Django Container Features:
- **Base Image**: Python 3.9-slim
- **Dependencies**: Django, django-auth-ldap, python-ldap, gunicorn
- **Database**: SQLite (lightweight for POC)
- **Web Server**: Gunicorn with 3 workers
- **Port**: 8000 (exposed via NSG rule)
- **Environment**: Dynamic configuration based on POC environment

### Docker Files:
- `django_app/Dockerfile` - Container definition
- `django_app/docker-compose.yml` - Container orchestration
- `django_app/requirements.txt` - Python dependencies
- `django_app/init_django.py` - Database initialization script

## Testing Your Environment

### Get Environment Information
After deployment, get your environment details:
```bash
cd terraform
terraform workspace select [environment_name]  # e.g., poc3
terraform output
```

### Test Django Application
```bash
# Test Django accessibility (replace with your Django VM IP)
curl http://[DJANGO_VM_IP]:8000/

# Test Django admin interface
curl http://[DJANGO_VM_IP]:8000/admin/
```

### Connect to Django Server via SSH
```bash
# SSH to Django VM (replace with your IP)
ssh -i ~/.ssh/id_rsa azureadmin@[DJANGO_VM_IP]

# Check Docker containers
docker-compose ps
docker-compose logs

# Restart Django container if needed
docker-compose restart
```

### Django Admin Access
- **URL**: `http://[DJANGO_VM_IP]:8000/admin/`
- **Username**: `fox`
- **Password**: `FoxAdmin2025!`

### Connect to Domain Controller
1. Go to Azure Portal → Virtual Machines → `vm-dc-[environment]`
2. Click "Connect" → "RDP"
3. Login with:
   - **Username**: `azureadmin`
   - **Password**: `TempAdminPass2025!` (hardcoded for POC)

### Manual Active Directory Installation
Since VM extensions had reliability issues, AD installation is now manual:

1. **RDP to Domain Controller** using the IP from terraform output
2. **Run PowerShell as Administrator**
3. **Execute the following commands**:

```powershell
# Install AD Domain Services
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Install the domain (system will reboot)
Import-Module ADDSDeployment
$SafeModePassword = ConvertTo-SecureString 'TempAdminPass2025!' -AsPlainText -Force
Install-ADDSForest -DomainName rule4.local -SafeModeAdministratorPassword $SafeModePassword -Force
```

4. **After reboot, create LDAP test users**:
```powershell
# Create test users for LDAP authentication
New-ADUser -Name 'testuser' -UserPrincipalName 'testuser@rule4.local' -AccountPassword (ConvertTo-SecureString 'TestPass123!' -AsPlainText -Force) -Enabled $true
New-ADUser -Name 'django' -UserPrincipalName 'django@rule4.local' -AccountPassword (ConvertTo-SecureString 'hardcoded-ldap-password-for-poc' -AsPlainText -Force) -Enabled $true
```

## Managing Environments

### List all environments:
```bash
cd terraform
terraform workspace list
```

### Switch to an environment:
```bash
cd terraform
terraform workspace select [environment_name]
```

### View resources in current environment:
```bash
cd terraform
terraform output
```

### Destroy an environment:
```bash
cd terraform
terraform workspace select [environment_name]
terraform destroy -auto-approve
```

### Check Django container status:
```bash
# SSH to Django VM
ssh azureadmin@[DJANGO_VM_IP]

# Check container status
cd /home/azureadmin/django_app
docker-compose ps
docker-compose logs --tail=50

# Restart if needed
docker-compose restart
```

## Prerequisites

1. **Azure CLI** installed and logged in:
   ```bash
   az login
   ```

2. **Terraform** installed (version ~> 1.0)

3. **SSH Key Pair** in `~/.ssh/id_rsa` (for VM access)

4. **Required Azure permissions**:
   - Contributor access to resource group `r4-onboarding-james`
   - Storage Account Contributor (for backend setup)

## Project Structure
```
.
├── django_app/                 # Django web application (Docker-based)
│   ├── Dockerfile              # Django container definition
│   ├── docker-compose.yml     # Container orchestration
│   ├── requirements.txt       # Python dependencies (minimal)
│   ├── init_django.py         # Database initialization
│   ├── manage.py              # Django management script
│   ├── create_superuser.py    # Django superuser creation
│   ├── django_app/            # Main Django application
│   │   ├── settings.py        # Django settings (LDAP configured)
│   │   ├── urls.py            # URL routing
│   │   └── wsgi.py            # WSGI application
│   ├── authentication/        # AD authentication app
│   └── README.md              # Django deployment documentation
├── terraform/                 # Infrastructure as Code
│   ├── main.tf                # Main Terraform configuration
│   ├── dc.tf                  # Domain Controller configuration
│   ├── django_vm.tf           # Django VM configuration (Docker setup)
│   ├── keyvault.tf            # Key Vault configuration
│   ├── network.tf             # Network configuration
│   ├── locals.tf              # Dynamic IP calculation
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   └── terraform.tfstate.d/   # Terraform workspace states
├── deploy_poc_v2.sh           # Modern Docker-based deployment script
├── deploy_poc.sh              # Legacy deployment script
├── create_ad_users.ps1        # AD user creation script
├── .gitignore                 # Git ignore rules
└── README.md                  # This file
```

## Deployment Phases

The `deploy_poc_v2.sh` script runs in phases:

1. **Phase 1: Infrastructure Deployment**
   - Creates VMs, networking, Key Vault
   - Sets up dynamic IP addressing

2. **Phase 2: VM Readiness Check**
   - Waits for SSH connectivity to Django VM
   - Waits for RDP connectivity to Domain Controller

3. **Phase 3: Docker Installation**
   - Installs Docker Engine and Docker Compose
   - Configures Docker service

4. **Phase 4: Django Application Deployment**
   - Copies Django application files
   - Creates dynamic environment configuration
   - Builds and starts Django container

5. **Phase 5: Active Directory Installation**
   - Provides manual installation instructions
   - Creates PowerShell scripts for AD setup

6. **Phase 6: Testing**
   - Tests Django application accessibility
   - Provides troubleshooting information

## Authentication Flow

1. User accesses Django application at `http://[DJANGO_VM_IP]:8000/`
2. Django redirects to login page
3. User enters AD credentials (e.g., testuser@rule4.local)
4. Django-LDAP authenticates against Windows DC via LDAP (port 389)
5. Upon success, user session is created with appropriate permissions

## Fox User (Django Admin)

The `fox` user is a **Django superuser** (not an Active Directory user):
- **Username**: `fox`
- **Password**: `FoxAdmin2025!` (hardcoded for POC)
- **Purpose**: Django admin interface access
- **Access**: `http://[DJANGO_VM_IP]:8000/admin/`

## Troubleshooting

### Django Container Issues
```bash
# SSH to Django VM
ssh azureadmin@[DJANGO_VM_IP]

# Check container status
docker-compose ps

# View logs
docker-compose logs

# Restart container
docker-compose restart

# Rebuild container
docker-compose up -d --build
```

### Network Connectivity Issues
```bash
# Test Django accessibility
curl http://[DJANGO_VM_IP]:8000/

# Check NSG rules (should allow port 8000)
az network nsg rule list --resource-group r4-onboarding-james --nsg-name nsg-[environment] --query "[?destinationPortRange=='8000']"
```

### Active Directory Issues
- Ensure manual AD installation completed successfully
- Check domain controller is responding on port 389
- Verify test users were created in AD

## Known Issues

1. **PowerShell Display Issues**: Terminal may show display errors - these are cosmetic and don't affect functionality
2. **VM Extension Reliability**: Switched to manual AD installation due to timing issues with VM extensions
3. **Key Vault Permissions**: Some environments may have Key Vault access restrictions

## Next Steps

1. **Complete Django deployment** if Phase 4 was interrupted
2. **Install Active Directory** manually on Domain Controller
3. **Test LDAP authentication** between Django and AD
4. **Deploy additional environments** as needed

## Assignment Requirements Status

- Azure environment in `r4-onboarding-james` resource group
- Windows domain `rule4.local` infrastructure ready
- Single domain controller (manual AD installation required)
- Ubuntu VM with Django app using Docker
- Django admin user named `fox`
- LDAPS for secure communication (requires AD installation)
- All configuration automated via code (except AD installation)

**Current Focus**: Complete Django container deployment and manual AD installation.


