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

# Main domain controller VM
resource "azurerm_windows_virtual_machine" "dc" {
  name                = "vm-dc-poc"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  size                = "Standard_B2s"  # Small size is fine for POC
  admin_username      = "azureuser"
  admin_password      = random_password.dc_admin.result

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

  identity {
    type = "SystemAssigned"
  }
}

# Additional disk for AD DS data
# Best practice is to keep AD data on a separate disk
resource "azurerm_managed_disk" "ad_data" {
  name                 = "disk-dc-data"
  location             = data.azurerm_resource_group.main.location
  resource_group_name  = data.azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"  # Keep Premium storage for better performance
  create_option        = "Empty"
  disk_size_gb        = 128  # Keep existing size
}

resource "azurerm_virtual_machine_data_disk_attachment" "ad_data" {
  managed_disk_id    = azurerm_managed_disk.ad_data.id
  virtual_machine_id = azurerm_windows_virtual_machine.dc.id
  lun                = "10"
  caching           = "None"  # No caching for AD data disk
}

# Initialize disk, install AD DS, and configure AD in one extension
resource "azurerm_virtual_machine_extension" "initialize_and_install_ad" {
  name                 = "initialize-and-install-ad"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on          = [azurerm_virtual_machine_data_disk_attachment.ad_data]

  protected_settings = jsonencode({
    "commandToExecute" = "powershell -Command \"Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel 'AD_Data' -Confirm:$false; Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools; $password = ConvertTo-SecureString '${random_password.dc_admin.result}' -AsPlainText -Force; Install-ADDSForest -DomainName 'rule4.local' -SafeModeAdministratorPassword $password -Force -InstallDns; Import-Module ActiveDirectory; New-ADOrganizationalUnit -Name 'Rule4' -Path 'DC=rule4,DC=local'; New-ADGroup -Name 'Django Users' -GroupScope Global -Path 'OU=Rule4,DC=rule4,DC=local'; New-ADUser -Name 'fox' -UserPrincipalName 'fox@rule4.local' -Path 'OU=Rule4,DC=rule4,DC=local' -AccountPassword $password -Enabled $true; Add-ADGroupMember -Identity 'Django Users' -Members 'fox'\""
  })
}

# Storage blob for DC configuration script
resource "azurerm_storage_blob" "dc_config" {
  name                   = "dc_config.ps1"
  storage_account_name   = azurerm_storage_account.diagnostics.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.module}/dc_config.ps1"
}

# Storage container for scripts
resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_name  = azurerm_storage_account.diagnostics.name
  container_access_type = "blob"
} 