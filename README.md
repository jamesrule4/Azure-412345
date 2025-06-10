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

**Active Directory**: Fully automated installation
- Infrastructure deployed with automated AD setup
- Domain controller automatically configured with rule4.local domain
- LDAP users and groups created automatically
- Zero manual intervention required

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
- **Phase 5**: Automated Active Directory installation and LDAP user creation
- **Phase 6**: Tests Django application and LDAP authentication

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

**Note**: Active Directory is now fully automated. The domain `rule4.local` and all LDAP users are created automatically during deployment.

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

### Destroy an environment:
```bash
cd terraform
terraform workspace select [environment_name]
terraform destroy -auto-approve
```

## Authentication Flow

1. User accesses Django application at `http://[DJANGO_VM_IP]:8000/`
2. Django redirects to login page
3. User enters AD credentials (e.g., testuser@rule4.local)
4. Django-LDAP authenticates against Windows DC via LDAP (port 389)
5. Upon success, user session is created with appropriate permissions

## LDAP Test Users (Created Automatically)

- **testuser@rule4.local** / `TestPass123!` (Django staff user)
- **adminuser@rule4.local** / `AdminPass123!` (Django admin user)
- **django@rule4.local** / (service account for LDAP binding)

## Fox User (Django Admin)

The `fox` user is a **Django superuser** (not an Active Directory user):
- **Username**: `fox`
- **Password**: `FoxAdmin2025!` (hardcoded for POC)
- **Purpose**: Django admin interface access
- **Access**: `http://[DJANGO_VM_IP]:8000/admin/`

## Assignment Requirements Status ✅

- ✅ Azure environment in `r4-onboarding-james` resource group
- ✅ Windows domain `rule4.local` **fully automated**
- ✅ Single domain controller with **automated AD installation**
- ✅ Ubuntu VM with Django app using Docker
- ✅ Django admin user named `fox`
- ✅ LDAP authentication **fully automated**
- ✅ **All configuration automated via code - zero manual steps**

**Status**: **Fully automated "push button" deployment achieved!**