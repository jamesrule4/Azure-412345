# Network interface for Django VMs
resource "azurerm_network_interface" "django" {
  count               = var.django_instance_count
  name                = "nic-django-poc-${count.index + 1}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address           = var.django_instance_ips[count.index]
  }
}

# Django application VMs
resource "azurerm_linux_virtual_machine" "django" {
  count               = var.django_instance_count
  name                = "vm-django-poc-${count.index + 1}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  size                = "Standard_B1s"  # Small size is fine for POC
  admin_username      = "azureuser"
  
  network_interface_ids = [
    azurerm_network_interface.django[count.index].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
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
  name                        = "allow-http"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "80"
  source_address_prefix      = var.rule4_ip
  destination_address_prefixes = var.django_instance_ips
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "django_ssh" {
  name                        = "allow-ssh"
  priority                    = 170
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = var.rule4_ip
  destination_address_prefixes = var.django_instance_ips
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
} 