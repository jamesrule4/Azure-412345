# Network interface for Django VM
resource "azurerm_network_interface" "django" {
  name                = "nic-django-${local.resource_suffix}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address           = local.django_instance_ips[0]  # Using first IP
  }
}

# Django application VM
resource "azurerm_linux_virtual_machine" "django" {
  name                = "vm-django-${local.resource_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  size                = "Standard_B1s"  # Small size is fine for POC
  admin_username      = var.admin_username
  
  network_interface_ids = [
    azurerm_network_interface.django.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")  # Make sure this exists
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Configure NSG rules for Django VMs
resource "azurerm_network_security_rule" "django_http" {
  name                        = "allow-http-${local.resource_suffix}"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "80"
  source_address_prefix      = "${var.rule4_ip}/32"
  destination_address_prefixes = local.django_instance_ips
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "django_ssh" {
  name                        = "allow-ssh-${local.resource_suffix}"
  priority                    = 170
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "${var.rule4_ip}/32"
  destination_address_prefixes = local.django_instance_ips
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
} 