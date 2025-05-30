# Network interface for the domain controller
# Using a static IP so I can reference it in DNS and other configs
resource "azurerm_network_interface" "dc" {
  name                = "nic-dc-poc"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address           = "10.0.1.10"  # Static IP for the DC
  }
}

# Allow LDAPS access from within the subnet
# Port 636 is for secure LDAP
resource "azurerm_network_security_rule" "dc_ldaps" {
  name                        = "allow-ldaps"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "636"
  source_address_prefix      = "10.0.1.0/24"  # Only allow from within the subnet
  destination_address_prefix = "10.0.1.10/32"  # DC's IP
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

# Allow RDP access from my IP only
resource "azurerm_network_security_rule" "dc_rdp" {
  name                        = "allow-rdp"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "3389"
  source_address_prefix      = var.admin_ip_address  # Using the variable instead of hardcoded IP
  destination_address_prefix = "10.0.1.10/32"  # DC's IP
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "random_password" "dc_admin" {
  length           = 20
  special          = true
  override_special = "!@#$%"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

# Main domain controller VM
resource "azurerm_windows_virtual_machine" "dc" {
  name                = "vm-dc-poc"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  size                = "Standard_B2s"  # Small size is fine for POC
  admin_username      = "azureadmin"
  admin_password      = random_password.dc_admin.result

  # Add system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  network_interface_ids = [
    azurerm_network_interface.dc.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = {
    environment = "poc"
  }
}

# Additional disk for AD DS data
# Best practice is to keep AD data on a separate disk
resource "azurerm_managed_disk" "ad_data" {
  name                 = "disk-dc-data"
  location             = data.azurerm_resource_group.main.location
  resource_group_name  = data.azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb        = 128
}

resource "azurerm_virtual_machine_data_disk_attachment" "ad_data" {
  managed_disk_id    = azurerm_managed_disk.ad_data.id
  virtual_machine_id = azurerm_windows_virtual_machine.dc.id
  lun                = "10"
  caching           = "None"  # No caching for AD data disk
}

# Initialize disk and install AD DS in one extension
# Combining these steps to avoid multiple extension issues
resource "azurerm_virtual_machine_extension" "initialize_and_install_ad" {
  name                 = "initialize-and-install-ad"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  depends_on          = [azurerm_virtual_machine_data_disk_attachment.ad_data]

  protected_settings = <<SETTINGS
  {
    "commandToExecute": "powershell -Command \"Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel 'AD_Data' -Confirm:$false; Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools; $password = ConvertTo-SecureString '${random_password.dc_admin.result}' -AsPlainText -Force; Install-ADDSForest -DomainName 'rule4.local' -SafeModeAdministratorPassword $password -Force -InstallDns\""
  }
  SETTINGS
} 