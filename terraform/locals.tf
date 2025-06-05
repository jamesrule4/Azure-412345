locals {
  # Extract environment number from workspace name (e.g., "poc2" -> 2)
  env_number = var.environment_number
  
  # Resource naming
  resource_suffix = terraform.workspace

  # Network ranges
  vnet_cidr = format("10.%d.0.0/16", var.environment_number)
  subnet_cidr = format("10.%d.1.0/24", var.environment_number)
  
  # Static IPs
  domain_controller_ip = format("10.%d.1.10", var.environment_number)
  django_instance_ips = [format("10.%d.1.11", var.environment_number)]  # Single Django VM per environment
} 