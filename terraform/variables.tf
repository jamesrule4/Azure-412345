variable "admin_ip_address" {
  description = "IP address allowed for RDP access"
  type        = string
  sensitive   = true
  default     = "0.0.0.0/0"  # Allow from anywhere for demo - restrict in production
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "rule4_ip" {
  description = "Rule4's egress IP address"
  type        = string
  default     = "65.140.106.10"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "r4-onboarding-james"
}

variable "environment_number" {
  description = "Environment number (e.g., 1 for poc1, 2 for poc2)"
  type        = number
  default     = 1  # Default to poc1
}

variable "vnet_cidr" {
  description = "CIDR block for the virtual network"
  type        = string
  default     = null  # Will be set by locals
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = null  # Will be set by locals
}

variable "ssh_public_key" {
  description = "SSH public key for Linux VM access"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC2oZPE1EoxQNUGPej8bx6QG1z6yzQVURR9UnX2zCZWzTFywNn88NvN6s1+XoHaQMyk7H4R5IW6P2nNph0rOvNqtQNw89e/+lmd0BAv9/iRH6b6D/PA9OnekK3YfFUs6Fxv0GtHt1iDbSrYttN7FJG0PF57u/tYmaUyLJPFZQtMdOvxMm82dlwfuNEImlto8AhIinOCLA9I9cCNDixGWSCUwi2lfb28f1PWC7C861OiizalZmTWtgiKxVRQSXKppRyG4FOGcRqWEhpv2Up4lUnCLK7ZC5h9GBQCWC5dixBJwKI0VL3xh5kefO72rT5anZaKj9DfR/UCxzB8Hi+OirhWJKyRZnBF9XtKvDD9Dp61exl636htJoO2be0UQm4TGy+qAvaX6OSYLx44sn9zE9BHAo66vzyBHOpmaP5q1TDiJiBw4367PbALXsVPVSwfyXR9vc5Bf6LTj98jKDFVtnyecy4og9QnueL4aM4NCS67mm/dcE5Dx1r6XLkWq97F5Dk= james@james-m4-mbp.local"
}

# Add any other variables needed for the configuration 