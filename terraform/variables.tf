variable "admin_ip_address" {
  description = "IP address allowed for RDP access"
  type        = string
  sensitive   = true
}

variable "domain_controller_ip" {
  description = "Static IP address for the domain controller"
  type        = string
  default     = "10.0.1.10"
}

variable "subnet_cidr" {
  description = "CIDR range for the main subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vnet_cidr" {
  description = "CIDR range for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}

variable "rule4_ip" {
  description = "Rule4's egress IP address"
  type        = string
  default     = "65.140.106.10"
}

variable "django_instance_count" {
  description = "Number of Django instances to create"
  type        = number
  default     = 2  # Default to 2 instances
}

variable "django_instance_ips" {
  description = "List of static IPs for Django instances"
  type        = list(string)
  default     = ["10.0.1.11", "10.0.1.12"]  # Add more IPs as needed
}

# Add any other variables needed for the configuration 