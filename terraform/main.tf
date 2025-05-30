# Configure the Azure provider
provider "azurerm" {
  features {}
  skip_provider_registration = true  # Skip provider registration since we don't have permissions
}

# Use existing resource group
data "azurerm_resource_group" "main" {
  name = "r4-onboarding-james"
} 