# Main virtual network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.resource_suffix}"
  address_space       = [local.vnet_cidr]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  lifecycle {
    create_before_destroy = true
  }
}

# Main subnet
resource "azurerm_subnet" "main" {
  name                 = "snet-${local.resource_suffix}"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.subnet_cidr]

  depends_on = [azurerm_virtual_network.main]

  lifecycle {
    create_before_destroy = true
  }
}

# Network security group
resource "azurerm_network_security_group" "main" {
  name                = "nsg-${local.resource_suffix}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  # Allow RDP to Domain Controller
  security_rule {
    name                       = "AllowRDPToDC"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "3389"
    source_address_prefixes   = [var.admin_ip_address]
    destination_address_prefix = "10.${var.environment_number}.1.10"
  }

  # Allow SSH to Django VM
  security_rule {
    name                       = "AllowSSHToDjangoVM"
    priority                   = 170
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "22"
    source_address_prefixes   = [var.admin_ip_address]
    destination_address_prefix = "10.${var.environment_number}.1.11"
  }

  # Allow HTTP to Django VM
  security_rule {
    name                       = "AllowHTTPToDjangoVM"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "80"
    source_address_prefixes   = [var.admin_ip_address]
    destination_address_prefix = "10.${var.environment_number}.1.11"
  }

  # Allow LDAP between VMs
  security_rule {
    name                       = "AllowLDAP"
    priority                   = 115
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "389"
    source_address_prefix     = local.subnet_cidr
    destination_address_prefix = "10.${var.environment_number}.1.10"
  }

  # Allow LDAPS between VMs
  security_rule {
    name                       = "AllowLDAPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "636"
    source_address_prefix     = local.subnet_cidr
    destination_address_prefix = "10.${var.environment_number}.1.10"
  }

  depends_on = [azurerm_subnet.main]

  lifecycle {
    create_before_destroy = true
  }
}

# Associate the NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id

  depends_on = [azurerm_network_security_group.main]
} 