# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "r4-onboarding-james"
    storage_account_name = "tfstater4poc"
    container_name      = "tfstate"
    key                = "environments.tfstate"
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true  # Skip automatic registration of Azure resource providers
}

# Get resource group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Random ID for unique storage account names
resource "random_id" "storage_account" {
  byte_length = 8
}

# Generate random passwords
resource "random_password" "dc_admin" {
  length           = 16
  special          = true
  override_special = "!@#$%&*"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
} 