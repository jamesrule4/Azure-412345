variable "admin_ip_address" {
  description = "IP address allowed for RDP access"
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
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
  default     = 4  # Default to poc4
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

# Add any other variables needed for the configuration 