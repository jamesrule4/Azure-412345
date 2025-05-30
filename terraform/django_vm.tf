# Network interface for Django VM
resource "azurerm_network_interface" "django" {
  name                = "nic-django-poc"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address           = "10.0.1.11"  # Static IP for Django VM
  }
}

# Ubuntu VM for Django application
resource "azurerm_linux_virtual_machine" "django" {
  name                  = "vm-django-poc"
  location              = data.azurerm_resource_group.main.location
  resource_group_name   = data.azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.django.id]
  size                  = "Standard_B2s"  # Same size as DC for consistency
  admin_username        = "azureuser"

  # Use SSH key authentication
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")  # We'll need to create this
  }

  os_disk {
    name                 = "disk-django-os"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "poc"
  }
}

# NSG rule for SSH access (temporary for development)
resource "azurerm_network_security_rule" "django_ssh" {
  name                        = "allow-ssh"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"  # TODO: Update to Rule4 IP before presentation
  destination_address_prefix  = "10.0.1.11/32"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

# NSG rule for HTTP access (temporary for development)
resource "azurerm_network_security_rule" "django_http" {
  name                        = "allow-http"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"  # TODO: Update to Rule4 IP before presentation
  destination_address_prefix  = "10.0.1.11/32"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

# Allow the Django VM to access Key Vault
resource "azurerm_key_vault_access_policy" "django" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.django.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
} 