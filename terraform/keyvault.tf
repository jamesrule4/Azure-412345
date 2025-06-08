# Get current client configuration from Azure
data "azurerm_client_config" "current" {}

# Create Key Vault
resource "azurerm_key_vault" "main" {
  name                = "kv-${local.resource_suffix}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id          = data.azurerm_client_config.current.tenant_id
  sku_name           = "standard"

  enabled_for_disk_encryption = true
  purge_protection_enabled    = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }
}

# Grant access to the current user
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover"
  ]
}

# Grant access to the DC VM
resource "azurerm_key_vault_access_policy" "dc" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_virtual_machine.dc.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Grant access to the Django VM
resource "azurerm_key_vault_access_policy" "django" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.django.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Generate a random password for Django admin
resource "random_password" "django_admin" {
  length  = 20
  special = true
}

# Store secrets
resource "azurerm_key_vault_secret" "domain_admin_password" {
  name         = "domain-admin-password-${local.env_number}"
  value        = random_password.dc_admin.result
  key_vault_id = azurerm_key_vault.main.id

  tags = {
    environment = terraform.workspace
  }

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

resource "azurerm_key_vault_secret" "django_admin_password" {
  name         = "django-admin-password-${local.env_number}"
  value        = random_password.django_admin.result
  key_vault_id = azurerm_key_vault.main.id

  tags = {
    environment = terraform.workspace
  }

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

resource "azurerm_key_vault_secret" "django_secret_key" {
  name         = "django-secret-key-${local.env_number}"
  value        = random_password.django_admin.result
  key_vault_id = azurerm_key_vault.main.id

  tags = {
    environment = terraform.workspace
  }

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

resource "azurerm_key_vault_secret" "ldap_bind_password" {
  name         = "ldap-bind-password-${local.env_number}"
  value        = random_password.dc_admin.result
  key_vault_id = azurerm_key_vault.main.id

  tags = {
    environment = terraform.workspace
  }

  depends_on = [azurerm_key_vault_access_policy.current_user]
} 