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
    destination_address_prefix = "${local.domain_controller_ip}/32"  # Only to DC
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
    destination_address_prefix = "${local.django_instance_ips[0]}/32"  # Only to first Django VM
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
    destination_address_prefix = "${local.domain_controller_ip}/32"  # Only to DC
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
    destination_address_prefix = "${local.django_instance_ips[0]}/32"  # Only to first Django VM
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