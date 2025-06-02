# Main virtual network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-poc"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
}

# Main subnet
resource "azurerm_subnet" "main" {
  name                 = "snet-poc"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network security group
resource "azurerm_network_security_group" "main" {
  name                = "nsg-poc"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  # Allow RDP from Rule4 IP only
  security_rule {
    name                       = "AllowRDPFromRule4"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "3389"
    source_address_prefix     = "${var.rule4_ip}/32"  # Rule4 egress IP
    destination_address_prefix = "10.0.1.10/32"      # Only to DC
  }

  # Allow SSH from Rule4 IP only
  security_rule {
    name                       = "AllowSSHFromRule4"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "22"
    source_address_prefix     = "${var.rule4_ip}/32"  # Rule4 egress IP
    destination_address_prefix = "10.0.1.11/32"      # Only to Django VM
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
    source_address_prefix     = "10.0.1.0/24"
    destination_address_prefix = "10.0.1.10/32"      # Only to DC
  }

  # Allow Django development server
  security_rule {
    name                       = "AllowDjangoDevServer"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "8000"
    source_address_prefix     = "${var.rule4_ip}/32"  # Rule4 egress IP
    destination_address_prefix = "10.0.1.11/32"      # Only to Django VM
  }
}

# Associate the NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
} 