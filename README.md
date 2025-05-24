# Azure-412345: Azure Self-Managed AD DS & Django POC

This project's goal is to deploy a self-managed Windows Active Directory Domain Services (AD DS) domain (single domain controller) in Azure and configure a Django application to authenticate users against that domain via LDAPS. Infrastructure provisioning and in-guest configuration will be scripted as code for repeatable, push-button deployments.

## Tool Selection & Implementation Decisions

### Infrastructure as Code
- **Terraform**: Primary IaC tool for Azure resource provisioning
  - Chosen for its Azure provider maturity and declarative syntax
  - Will manage: VNet, VMs, NSGs, Key Vault

### Domain Controller Configuration
- **PowerShell Scripts**: For Windows Server and AD DS configuration
  - Simpler than DSC for POC purposes
  - Will handle: AD DS installation, domain promotion, DNS configuration

### Django Application Setup
- **Bash Scripts**: For Ubuntu and Django configuration
  - Direct and simple approach for POC
  - Will handle: Python/Django installation, LDAPS configuration

### Security & Secrets
- **Azure Key Vault**: For secrets management
  - Will store: AD admin password, Django secrets, certificates
- **Network Security Groups**: For access control
  - Will restrict access to Rule4's egress IP only
  - Will allow LDAPS (636) between VMs

### Resource Requirements
- **Domain Controller**: Windows Server 2022 (B2s)
  - 2 vCPUs, 4GB RAM
  - Estimated cost: ~$40/month
- **Django Server**: Ubuntu 22.04 (B1s)
  - 1 vCPU, 2GB RAM
  - Estimated cost: ~$15/month
- **Total Estimated Cost**: ~$55/month

## Pending Items
- [ ] Rule4 egress IP address for NSG configuration
- [ ] Domain name selection
- [ ] Initial AD admin credentials
- [ ] Django application requirements

## Roadmap

Future updates will cover:
- Detailed implementation walkthroughs and configuration examples
- Secrets management and security best practices
- Monitoring, cost estimation, and scaling considerations


