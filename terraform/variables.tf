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

# Add any other variables needed for the configuration 