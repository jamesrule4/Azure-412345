# Azure POC Environment

This is my test environment for setting up a Windows-based Active Directory infrastructure in Azure. I'm building this to learn and test AD integration scenarios.

## What's Included

### Infrastructure
- Virtual Network (10.0.0.0/16) with dedicated subnet for domain resources
- Windows Server 2022 Domain Controller
- Network Security Groups for access control
- Storage account for VM diagnostics

### Features
- Automated AD DS installation and configuration
- LDAPS enabled by default
- Separate data disk for AD data (best practice)
- Basic security rules for RDP and LDAPS access

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

## Security Notes

- The domain admin password is stored in Terraform state
- NSG rules are intentionally permissive for testing
- Remember to clean up with `terraform destroy` when done

## Project Status & Next Steps

- [x] Get Contributor access to the Azure resource group
- [x] Deploy network and NSG with Terraform
- [x] Deploy Windows Server VM for Domain Controller
- [x] Configure AD DS with PowerShell script
- [x] Set up initial NSG rules
- [ ] Deploy Ubuntu VM for Django app
- [ ] Configure Django app with Bash script
- [ ] Set up Key Vault for secrets
- [ ] Configure LDAPS certificates
- [ ] Add monitoring and backup
- [ ] Lock down NSG rules to specific IPs

## My Azure Roles

These are the roles assigned to me in my Azure subscription:

### Core Infrastructure Roles
- **Network Contributor**: For managing VNet and NSG configurations
- **Virtual Machine Contributor**: For creating and managing VMs
- **Storage Account Contributor**: For managing diagnostics and VM storage

### Access & Security Roles
- **Key Vault Administrator**: For managing Key Vault and its policies
- **Key Vault Reader**: For viewing Key Vault properties
- **Key Vault Secrets User**: For reading secrets from Key Vault
- **Virtual Machine Administrator Login**: For admin RDP access to VMs
- **Virtual Machine User Login**: For standard RDP access to VMs

### Automation Roles
- **Automation Operator**: For managing automation runbooks and jobs


