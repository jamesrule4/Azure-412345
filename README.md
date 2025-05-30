# Azure POC Environment

This is my test environment for setting up a Windows-based Active Directory infrastructure in Azure with Django LDAP authentication.

## What's Included

### Infrastructure
- Virtual Network (10.0.0.0/16) with dedicated subnet for domain resources
- Windows Server 2022 Domain Controller
- Network Security Groups for access control
- Storage account for VM diagnostics
- Key Vault for secret management

### Features
- Automated AD DS installation and configuration
- LDAPS enabled by default
- Separate data disk for AD data (best practice)
- Basic security rules for RDP and LDAPS access
- Django web application with AD authentication

## Components & Roles

### Infrastructure Components
- **Virtual Network (VNet)**
  - Main network space (10.0.0.0/16)
  - Handles all internal communication
  - Segmented into subnets for different workloads

- **Subnet**
  - Primary subnet (10.0.1.0/24)
  - Hosts domain resources and VMs
  - Protected by NSG rules

- **Network Security Group (NSG)**
  - Controls inbound/outbound traffic
  - Allows RDP access from my IP
  - Permits LDAPS (636) within the subnet
  - Blocks unwanted traffic

### Virtual Machines
- **Domain Controller (Windows Server 2022)**
  - Hosts Active Directory Domain Services
  - Static IP: 10.0.1.10
  - B2s size (2 vCPUs, 4GB RAM)
  - Separate data disk for AD data
  - System-managed identity for Azure integration

### Storage
- **Diagnostics Storage Account**
  - Standard LRS tier
  - Stores boot diagnostics
  - VM performance metrics
  - Random name for uniqueness

### Active Directory
- **AD DS Role**
  - Primary domain controller
  - DNS server for domain
  - LDAP authentication
  - Group Policy management
  - User and computer management

### Security Components
- **NSG Rules**
  - RDP (3389): Limited to specific IPs
  - LDAPS (636): Internal subnet only
  - Custom rules as needed

### Terraform Components
- **Provider Configuration**
  - AzureRM provider
  - Random provider for passwords
  - State stored locally

- **Resource Organization**
  - Network (network.tf)
  - Domain Controller (dc.tf)
  - Storage (storage.tf)
  - Outputs (outputs.tf)

## Prerequisites

- Azure subscription with contributor access
- Terraform installed locally
- Azure CLI installed and logged in

## Getting Started

1. Clone this repo
2. Update your IP in `dc.tf` for RDP access
3. Run:
```bash
terraform init
terraform apply
```

## Network Layout

- VNet: 10.0.0.0/16 (65k addresses)
- Main Subnet: 10.0.1.0/24 (254 usable IPs)
- DC IP: 10.0.1.10 (static assignment)

## Required Azure Permissions

For this POC, the following Azure roles are required:

### Core Infrastructure Roles
- **Network Contributor**: For managing VNet and NSG configurations
- **Virtual Machine Contributor**: For creating and managing VMs
- **Storage Account Contributor**: For managing diagnostics and VM storage

### Key Vault Roles (Critical)
- **Key Vault Contributor**: For creating and managing Key Vaults
- **Key Vault Administrator**: For managing Key Vault access policies
- **Key Vault Secrets Officer**: For managing secrets within Key Vault

### Identity & Access Roles
- **Virtual Machine Administrator Login**: For admin RDP access to VMs
- **Virtual Machine User Login**: For standard RDP access to VMs
- **Managed Identity Operator**: For managing system-assigned identities

## Project Status & Next Steps

### Completed
- [x] Get Contributor access to the Azure resource group
- [x] Deploy network and NSG with Terraform
- [x] Deploy Windows Server VM for Domain Controller
- [x] Configure AD DS with PowerShell script
- [x] Set up initial NSG rules
- [x] Configure LDAPS certificates
- [x] Set up Key Vault for secrets
- [x] Create AD groups for Django authentication

### In Progress
- [ ] Configure DC to use Key Vault for admin password
- [ ] Deploy Django application VM
- [ ] Set up Django LDAP authentication
- [ ] Test end-to-end authentication flow

### Upcoming
- [ ] Add monitoring and backup
- [ ] Lock down NSG rules to specific IPs
- [ ] Document deployment process
- [ ] Create cleanup scripts

## Security Notes

- Secrets are stored in Azure Key Vault
- NSG rules are intentionally permissive for testing
- LDAPS is enabled and required for secure authentication
- Remember to clean up with `terraform destroy` when done

## TODO Items

### Security
- [ ] Restrict access to Rule4's egress IP only (Lumen network)
  - Currently allowing wider access for development
  - Will need to update NSG rules before presentation
  - Required Rule4's IP address

### Infrastructure
- [ ] Complete Django app deployment
- [ ] Test AD authentication
- [ ] Document monthly cost estimates


