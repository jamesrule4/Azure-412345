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
}

provider "azurerm" {
  features {}
  skip_provider_registration = true  # Skip provider registration since we don't have permissions
}

# Instead of creating the resource group, reference the existing one
data "azurerm_resource_group" "main" {
  name = "r4-onboarding-james"
} 