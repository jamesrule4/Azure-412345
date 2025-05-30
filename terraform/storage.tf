# Random suffix for storage account name since they must be globally unique
resource "random_id" "storage_account" {
  byte_length = 8
}

# Storage account for VM boot diagnostics
resource "azurerm_storage_account" "diagnostics" {
  name                     = "diag${lower(random_id.storage_account.hex)}"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                = data.azurerm_resource_group.main.location
  account_tier             = "Standard"  # Basic tier is fine for diagnostics
  account_replication_type = "LRS"      # Local redundancy is sufficient

  tags = {
    environment = "poc"
  }
} 