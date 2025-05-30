data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                        = "kvr4poc${lower(random_id.storage_account.hex)}"
  location                    = data.azurerm_resource_group.main.location
  resource_group_name         = data.azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false  # Disabled for POC, enable for production
  sku_name                    = "standard"

  # Access policy for the current user/service principal
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update",
      "Import", "Backup", "Restore", "Recover"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Backup",
      "Restore", "Recover"
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Update",
      "Import", "Backup", "Restore", "Recover"
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

# Separate access policy for the domain controller's managed identity
# This needs to be created after the VM since it depends on the identity
resource "azurerm_key_vault_access_policy" "dc" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  # Only create this policy after the VM has been created and has an identity
  object_id    = coalesce(try(azurerm_windows_virtual_machine.dc.identity[0].principal_id, null), "00000000-0000-0000-0000-000000000000")

  secret_permissions = [
    "Get", "List"
  ]

  depends_on = [
    azurerm_windows_virtual_machine.dc,
    azurerm_key_vault.main
  ]
}

# Output the Key Vault name for reference
output "key_vault_name" {
  value = azurerm_key_vault.main.name
} 