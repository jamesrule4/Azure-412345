# Get current client configuration
data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = "kv-${terraform.workspace}-${random_id.storage_account.hex}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Purge"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Purge"
    ]

    storage_permissions = [
      "Get", "List", "Set", "Delete", "Update", "Recover", "Purge"
    ]
  }

  # Access policy for Django VM system-assigned identity
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_linux_virtual_machine.django.identity[0].principal_id

    secret_permissions = [
      "Get", "List"
    ]
  }

  tags = {
    Environment = terraform.workspace
  }
}

# Generate passwords for AD services only
resource "random_password" "django_admin" {
  length           = 16
  special          = true
  override_special = "!@#$%&*"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "random_password" "django_secret_key" {
  length  = 50
  special = true
}

resource "random_password" "ldap_bind_password" {
  length           = 16
  special          = true
  override_special = "!@#$%&*"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# Key Vault Secrets
resource "azurerm_key_vault_secret" "domain_admin_password" {
  name         = "domain-admin-password-${terraform.workspace}"
  value        = random_password.dc_admin.result
  key_vault_id = azurerm_key_vault.main.id
  
  tags = {
    Environment = terraform.workspace
  }
}

resource "azurerm_key_vault_secret" "django_admin_password" {
  name         = "django-admin-password-${terraform.workspace}"
  value        = random_password.django_admin.result
  key_vault_id = azurerm_key_vault.main.id
  
  tags = {
    Environment = terraform.workspace
  }
}

resource "azurerm_key_vault_secret" "django_secret_key" {
  name         = "django-secret-key-${terraform.workspace}"
  value        = random_password.django_secret_key.result
  key_vault_id = azurerm_key_vault.main.id
  
  tags = {
    Environment = terraform.workspace
  }
}

resource "azurerm_key_vault_secret" "ldap_bind_password" {
  name         = "ldap-bind-password-${terraform.workspace}"
  value        = random_password.ldap_bind_password.result
  key_vault_id = azurerm_key_vault.main.id
  
  tags = {
    Environment = terraform.workspace
  }
} 