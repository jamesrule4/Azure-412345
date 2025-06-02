# Get current Azure client configuration
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                        = "kvr4poc${lower(random_id.storage_account.hex)}"
  location                    = data.azurerm_resource_group.main.location
  resource_group_name         = data.azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false  # Disabled for POC
  sku_name                    = "standard"

  # Access policy for the current user/service principal
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete"
    ]
  }

  tags = {
    environment = "poc"
  }
}

# Store the domain admin password in Key Vault
resource "azurerm_key_vault_secret" "domain_admin_password" {
  name         = "domain-admin-password"
  value        = random_password.dc_admin.result
  key_vault_id = azurerm_key_vault.main.id

  tags = {
    environment = "poc"
  }
}

# Key Vault access policy for DC
resource "azurerm_key_vault_access_policy" "dc" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_virtual_machine.dc.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Key Vault access policy for Django VMs
resource "azurerm_key_vault_access_policy" "django" {
  count = var.django_instance_count

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.django[count.index].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Output the Key Vault name for reference
output "key_vault_name" {
  value = azurerm_key_vault.main.name
} 