# Main virtual network for the POC environment
resource "azurerm_virtual_network" "main" {
  name                = "vnet-poc"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  address_space       = [var.vnet_cidr]

  tags = {
    environment = "poc"
  }
}

# Subnet for domain resources
resource "azurerm_subnet" "main" {
  name                 = "snet-poc"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

# Network security group for basic access control
resource "azurerm_network_security_group" "main" {
  name                = "nsg-poc"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  # Secure LDAPS access from within subnet only
  security_rule {
    name                       = "allow-ldaps"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "636"
    source_address_prefix     = var.subnet_cidr
    destination_address_prefix = var.domain_controller_ip
  }

  # RDP access from admin IP only
  security_rule {
    name                       = "allow-rdp"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "3389"
    source_address_prefix     = var.admin_ip_address
    destination_address_prefix = var.domain_controller_ip
  }

  tags = {
    environment = "poc"
  }
}

# Associate the NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
} 