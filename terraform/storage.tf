# Storage account for diagnostics and scripts
resource "azurerm_storage_account" "diagnostics" {
  name                     = "diag${random_id.storage_account.hex}"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = local.resource_suffix
  }
} 