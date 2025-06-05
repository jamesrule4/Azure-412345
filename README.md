# Azure Active Directory Integration POC

This project demonstrates a proof-of-concept environment for deploying isolated Windows Active Directory domains with Django web applications in Azure. The goal is to create a self-contained customer environment deployable on demand with minimal interaction—that can scale to thousands of identical environments.

## Quick Start
```bash
# Clone and setup
git clone <repository-url>
cd Azure-412345

# Set up environment variables
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_KEY_VAULT_URL="https://kvr4pocdc30ed2f6a96b645.vault.azure.net/"

# Deploy infrastructure
cd terraform
terraform init
terraform apply

# Deploy Django application
cd ../django_app
./setup.sh
```

## Project Overview

### Core Requirements
1. Deploy a Windows domain and Active Directory Domain Controller (AD DC)
2. Deploy a Django application that authenticates against that domain
3. All configuration and deployment must be code/script-based (no GUI steps)
4. Ensure secure communication between components
5. Create a Django admin user named "fox"

### Azure Permissions
Current assigned roles in resource group:
- Network Contributor
- Virtual Machine Contributor
- Key Vault Administrator
- Key Vault Reader
- Key Vault Secrets User
- Virtual Machine Administrator Login
- Storage Account Contributor
- Key Vault Contributor

## Current Architecture

### Infrastructure Components
```
┌─────────────────────────────────────────────────────────────────┐
│                         Azure VNet (10.0.0.0/16)                 │
│   ┌──────────────────────────┐      ┌───────────────────────┐   │
│   │    Domain Controller     │      │     Django Server     │   │
│   │    Windows Server 2022   │      │     Ubuntu 22.04      │   │
│   │    10.0.1.10            │      │     10.0.1.11         │   │
│   │    - Active Directory    │◄────►│     - Django App      │   │
│   │    - DNS Server         │      │     - LDAP Client     │   │
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

### Deployed Resources
- **Virtual Network**: 
  - Name: vnet-poc
  - Address Space: 10.0.0.0/16
  - Subnet: 10.0.1.0/24
- **Virtual Machines**:
  - Domain Controller (vm-dc-poc):
    - Size: B2s (2 vCPUs, 4GB RAM)
    - OS: Windows Server 2022
    - Disk: Premium SSD
    - Static IP: 10.0.1.10
  - Django Server (vm-django-poc):
    - Size: B1s (1 vCPU, 2GB RAM)
    - OS: Ubuntu 22.04 LTS
    - Disk: Standard SSD
    - Static IP: 10.0.1.11
- **Network Security Groups**:
  - nsg-poc (main)
  - vm-dc-nsg (DC-specific)
  - Rules configured:

#### Inbound Security Rules
| Priority | Name                 | Port  | Protocol | Source             | Destination | Action |
|----------|---------------------|-------|----------|-------------------|-------------|--------|
| 110      | allow-ldap          | 636   | Tcp      | 10.0.1.0/24       | 10.0.1.10   | Allow  |
| 120      | allow-rdp           | 3389  | Tcp      | 73.153.182.189/32 | 10.0.1.10   | Allow  |
| 160      | allow-django-dev    | 8000  | Tcp      | 73.153.182.189/32 | 10.0.1.11   | Allow  |
| 65000    | AllowVnetInBound    | Any   | Any      | VirtualNetwork    | VirtualNetwork| Allow |
| 65001    | AllowAzureLoadBalancerInBound | Any | Any | AzureLoadBalancer | Any     | Allow  |
| 65500    | DenyAllInBound      | Any   | Any      | Any               | Any         | Deny   |

#### Outbound Security Rules
| Priority | Name                   | Port | Protocol | Source        | Destination | Action |
|----------|------------------------|------|----------|---------------|-------------|--------|
| 65000    | AllowVnetOutBound     | Any  | Any      | VirtualNetwork| VirtualNetwork| Allow |
| 65001    | AllowInternetOutBound | Any  | Any      | Any          | Internet    | Allow  |
| 65500    | DenyAllOutBound       | Any  | Any      | Any          | Any         | Deny   |

- **Key Vault**: kvr4pocdc30ed2f6a96b645
  - Secrets:
    - django-secret-key
    - admin-password
    - ldap-bind-password
  - Purpose: Secure secret management for infrastructure
  - Access: Managed via RBAC and access policies

- **Storage Account**: diagdc30ed2f6a96b645
  - Purpose: VM diagnostics
  - Type: Standard LRS
  - Used for: VM boot diagnostics and monitoring

## Project Status and Features

### Completed Features
- [x] Basic infrastructure deployment
- [x] Windows DC with AD DS
- [x] Ubuntu VM with Python/Django
- [x] Key Vault integration
- [x] Network security groups
- [x] Basic deployment scripts

### In Progress
- [ ] AD DC configuration automation
- [ ] Django deployment automation
- [ ] End-to-end authentication testing
- [ ] Documentation improvements

### Planned Features
- [ ] Monitoring setup
- [ ] Backup configuration
- [ ] Cost optimization

## Development Workflow

### Project Structure
```
.
├── django_app/                 # Django web application
│   ├── authentication/         # AD DC authentication app
│   │   ├── management/        # Django management commands
│   │   │   └── commands/      # Custom commands for AD DC setup
│   │   └── templates/         # Authentication templates
│   ├── config/                # Django settings & configuration
│   │   ├── settings.py        # Main Django settings
│   │   ├── keyvault.py       # Azure Key Vault integration
│   │   └── urls.py           # URL routing
│   └── requirements.txt       # Python dependencies
├── scripts/                   # Deployment scripts
│   ├── linux/                # Ubuntu/Django VM scripts
│   │   └── deploy.sh         # Django deployment script
│   ├── windows/              # Windows DC scripts
│   │   └── configure-ad.ps1  # AD DS configuration script
│   └── create_environment.sh # Environment creation script
├── terraform/                # Infrastructure as Code
│   ├── main.tf              # Main Terraform configuration
│   ├── network.tf           # Network & NSG definitions
│   ├── dc.tf               # Domain Controller configuration
│   ├── django_vm.tf        # Django VM configuration
│   ├── keyvault.tf         # Key Vault configuration
│   ├── storage.tf          # Storage account configuration
│   ├── variables.tf         # Input variables
│   ├── locals.tf            # Local variables for workspaces
│   └── outputs.tf           # Output definitions
└── README.md                # Project documentation
```

### Workspace-Based Deployment
Each environment is managed through Terraform workspaces:
```bash
# Create and switch to a new environment
terraform workspace new poc2

# Deploy the environment
terraform apply

# List available environments
terraform workspace list

# Switch between environments
terraform workspace select poc1
```

Each workspace maintains its own state and creates isolated resources with unique names based on the workspace name (e.g., vm-dc-poc2, nic-django-poc2).

### Deployment Steps
1. Infrastructure provisioning (Terraform)
2. Domain Controller configuration (PowerShell)
3. Django application deployment (Bash)
4. Authentication setup and testing

## Cost Estimation
Monthly cost for a single environment:
- B2s VM (DC): ~$30/month
- B1s VM (Django): ~$15/month
- Storage: ~$5/month
- Key Vault: Free tier
- Network: Minimal costs
Total: ~$55/month

## Next Steps
1. Complete AD DC automation 
2. Implement Django deployment automation
3. Set up authentication flow
4. Restrict external access to Rule4's egress IP
5. Create deployment documentation

## Security Considerations
- All configuration and secrets managed via Azure Key Vault
- LDAPS for secure authentication
- NSG rules following least-privilege principle
- Network isolation between environments

## Authentication Flow

1. User accesses Django application
2. Django redirects to login page
3. User enters AD credentials
4. Django-LDAP authenticates against Windows DC:
   - Verifies credentials via LDAPS (port 636)
   - Checks group memberships
   - Creates/updates local Django user
5. Upon success:
   - User session created
   - User permissions synced from AD groups
   - User redirected to home page
6. For admin user "fox":
   - Created automatically during deployment
   - Granted Django superuser privileges
   - Can access Django admin interface

## Getting Started

### Prerequisites
Before starting, ensure you have:
- Azure CLI (latest version)
- Terraform (>= 1.0.0)
- Python (>= 3.9)
- Git

### Development Setup
1. Clone and configure:
   ```bash
   # Clone repository
   git clone <repository-url>
   cd Azure-412345

   # Configure Azure authentication
   az login
   az account set --subscription <subscription-id>

   # Set required environment variables
   export AZURE_SUBSCRIPTION_ID="your-subscription-id"
   export AZURE_KEY_VAULT_URL="https://kvr4pocdc30ed2f6a96b645.vault.azure.net/"
   ```

2. Infrastructure deployment:

   # Deploy Azure resources
   cd terraform
   terraform init
   terraform plan    # Review changes
   terraform apply   # Deploy infrastructure
   ```

3. Application deployment:
   ```bash
   # Set up Django environment
   cd ../django_app
   python -m venv venv
   source venv/bin/activate  # or `venv\Scripts\activate` on Windows
   pip install -r requirements.txt
   ./setup.sh
   ```

### Verification Steps
1. Check infrastructure:
   ```bash
   az vm list -g r4-onboarding-james -o table
   az network vnet list -g r4-onboarding-james -o table
   ```

2. Verify AD DC:
   - RDP to DC (10.0.1.10)
   - Check AD Users and Computers
   - Verify LDAPS certificate

3. Test Django application:
   - Access Django admin: https://10.0.1.11/admin
   - Try logging in with AD credentials
   - Check LDAP group synchronization

## References

- [Azure Documentation](https://docs.microsoft.com/azure)
- [Django-LDAP Documentation](https://django-auth-ldap.readthedocs.io/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## Self-Contained Environments

### Overview
The project supports deploying multiple isolated environments, each containing:
- A dedicated Domain Controller (DC)
- A Django application server
- Isolated networking
- Environment-specific secrets

### Deployment Pattern
Each environment follows this pattern:
```
Environment N:
├── Network (vnet-pocN)
│   └── Subnet (10.N.1.0/24)
├── Domain Controller (vm-dc-pocN)
└── Django Server (vm-django-pocN)
```

### Resource Naming
Resources are numbered sequentially (poc1, poc2, etc.):
- Virtual Machines: vm-dc-poc1, vm-django-poc1
- Network Interfaces: nic-dc-poc1, nic-django-poc1
- Network Security Groups: nsg-poc1
- Virtual Networks: vnet-poc1

### Network Isolation
Each environment gets its own address space:
- Environment 1: 10.1.0.0/16
- Environment 2: 10.2.0.0/16
- Environment N: 10.N.0.0/16

### Secret Management
All secrets are stored in the central Key Vault with environment-specific prefixes:
- django-secret-key-1, django-secret-key-2
- admin-password-1, admin-password-2
- ldap-bind-password-1, ldap-bind-password-2


