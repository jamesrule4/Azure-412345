# Azure Active Directory Integration POC

This project demonstrates automated deployment of isolated Windows Active Directory domains with Django web applications in Azure using Docker containerization. Each deployment creates a self-contained environment that can scale to thousands of identical environments.

## Current Status

**Infrastructure**: Deployed and operational
- **Django VM**: Ubuntu 22.04 with Docker
- **Domain Controller**: Windows Server 2022 
- **Key Vault**: Automated secret management
- **Network**: Isolated VNet with dynamic IP addressing and VM-to-VM communication

**Django Application**: Optimized Docker Hub deployment
- Infrastructure deployed successfully
- Docker installed and configured
- Django container pulled from Docker Hub (`jamesrule4/django-app:latest`)
- Multi-platform Docker image (AMD64/ARM64) for compatibility
- Application accessible via browser

**Active Directory**: Automated installation with completion needed
- Infrastructure deployed with automated AD setup scripts
- Domain controller configured for rule4.local domain
- LDAP installation may require completion for full functionality
- Network connectivity between VMs established

## Quick Start

Deploy a new environment with optimized Docker deployment:

```bash
./deploy_poc_v2.sh [environment_number]  # Deploy POC environment
```

The script automatically:
- **Phase 1**: Deploys infrastructure (VMs, networking, Key Vault)
- **Phase 2**: Waits for VMs to be ready with connectivity checks
- **Phase 3**: Installs Docker on Django VM
- **Phase 4**: Pulls and runs Django application from Docker Hub
- **Phase 5**: Initiates automated Active Directory installation
- **Phase 6**: Monitors AD installation progress

## What Gets Created

Each environment includes:
- **Windows Domain Controller** with automated AD installation scripts
- **Django Application Server** running from Docker Hub container
- **Virtual Network** with isolated IP ranges (10.X.0.0/16)
- **Azure Key Vault** for secret management
- **Network Security Groups** with VM-to-VM communication and web access
- **Optimized Docker deployment** using pre-built multi-platform images

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
│   │    10.X.1.10            │◄────►│     10.X.1.11         │   │
│   │    - Active Directory    │      │     - Docker Engine   │   │
│   │    - DNS Server         │      │     - Django Container│   │
│   │    - LDAP (port 389)    │      │     - LDAP Client     │   │
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

## Optimized Docker Deployment

The Django application uses an optimized Docker Hub deployment for faster and more reliable deployments:

### Docker Hub Integration:
- **Image**: `jamesrule4/django-app:latest`
- **Multi-platform**: Supports both AMD64 and ARM64 architectures
- **Pre-built**: No local building required, faster deployment
- **Consistent**: Same image across all environments

### Django Container Features:
- **Base Image**: Python 3.9-slim
- **Dependencies**: Django, django-auth-ldap, python-ldap, gunicorn
- **Database**: SQLite (lightweight for POC)
- **Web Server**: Gunicorn with multiple workers
- **Port**: 8000 (exposed via NSG rule)
- **Environment**: Dynamic configuration based on POC environment

### Network Security:
- **Port 8000**: Django application access
- **Port 22**: SSH access to Django VM
- **Port 3389**: RDP access to Domain Controller
- **Port 389**: LDAP communication (when AD is ready)
- **VNet Communication**: VM-to-VM internal communication enabled

## Testing the Environment

After deployment, environment details can be retrieved with:

### Get Environment Information
After deployment, get your environment details:
```bash
cd terraform
terraform workspace select [environment_name]  # e.g., poc44
terraform output
```

### Test Django Application
```bash
# Test Django accessibility (replace with Django VM IP)
curl http://10.[environment_number].1.11:8000/

# Test Django admin interface
curl http://[DJANGO_VM_IP]:8000/admin/

# Or open in browser
open http://[DJANGO_VM_IP]:8000/
```

### Test Database Connection
```bash
# Connect to Django container
docker exec -it rule4-django-minimal python manage.py shell

# Test database
python manage.py showmigrations
```

### Test Network Connectivity
```bash
# SSH to Django VM (replace with actual IP)
ssh azureadmin@[django_vm_public_ip]
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
   - **Password**: Retrieved from Key Vault or use default

**Note**: Active Directory installation is automated but may require completion. Check LDAP port 389 connectivity to verify AD readiness.

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

### Clean up all environments (except tfstater4poc):
```bash
# Destroy all POC environments while preserving Terraform state storage
cd terraform
for workspace in $(terraform workspace list | grep poc | tr -d '*' | xargs); do
  terraform workspace select $workspace
  terraform destroy -auto-approve
done
terraform workspace select default
```

## Authentication Flow

1. User accesses Django application at `http://[DJANGO_VM_IP]:8000/`
2. Django redirects to login page
3. User enters AD credentials (e.g., testuser@rule4.local)
4. Django-LDAP authenticates against Windows DC via LDAP (port 389)
5. Upon success, user session is created with appropriate permissions

## LDAP Test Users (Created when AD is ready)

- **testuser@rule4.local** / `TestPass123!` (Django staff user)
- **adminuser@rule4.local** / `AdminPass123!` (Django admin user)
- **django@rule4.local** / (service account for LDAP binding)

## Fox User (Django Admin)

The `fox` user is a **Django superuser** (not an Active Directory user):
- **Username**: `fox`
- **Password**: `FoxAdmin2025!`
- **Purpose**: Django admin interface access
- **Access**: `http://[DJANGO_VM_IP]:8000/admin/`

## Troubleshooting

### Common Issues:

**Django Container Not Running:**
```bash
ssh azureadmin@[DJANGO_VM_IP]
docker ps  # Check if container is running
docker logs django-poc-[environment_number]  # Check logs
```

**VM-to-VM Connectivity Issues:**
```bash
# From Django VM, test connectivity to DC
ping 10.[environment_number].1.10
telnet 10.[environment_number].1.10 389  # Test LDAP port
```

**Active Directory Not Ready:**
- Check if port 389 (LDAP) is accessible from Django VM
- RDP into Domain Controller to check AD installation status
- AD installation may take 15-30 minutes to complete fully

## Assignment Requirements Status ✅

- ✅ Azure environment in `r4-onboarding-james` resource group
- ✅ Windows domain `rule4.local` with automated setup
- ✅ Single domain controller with automated AD installation scripts
- ✅ Ubuntu VM with Django app using optimized Docker deployment
- ✅ Django admin user named `fox`
- ✅ LDAP authentication capability (when AD installation completes)
- ✅ Optimized deployment using Docker Hub for faster, consistent deployments
- ✅ Network security configured for VM-to-VM communication

**Status**: **Optimized automated deployment with Docker Hub integration**