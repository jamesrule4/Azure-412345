terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true  # Skip resource provider registration
}

# Use existing resource group
data "azurerm_resource_group" "main" {
  name = "r4-onboarding-james"
}

# Generate a random password for the DC admin
resource "random_password" "dc_admin" {
  length           = 16
  special          = true
  override_special = "!@#$%&*"
  min_special      = 2
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
} 