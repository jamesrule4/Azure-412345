# Public IP for Domain Controller
resource "azurerm_public_ip" "dc" {
  name                = "pip-dc-${local.resource_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                = "Standard"
}

# Network interface for the domain controller
# Static IP for DNS and config references
resource "azurerm_network_interface" "dc" {
  name                = "nic-dc-${local.resource_suffix}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address           = local.domain_controller_ip
    public_ip_address_id         = azurerm_public_ip.dc.id
  }
}

# Windows VM for Domain Controller
resource "azurerm_windows_virtual_machine" "dc" {
  name                = "vm-dc-${local.resource_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
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

# Additional disk for AD data
resource "azurerm_managed_disk" "ad_data" {
  name                 = "disk-dc-data-${local.resource_suffix}"
  location             = data.azurerm_resource_group.main.location
  resource_group_name  = data.azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

# Attach the data disk to the VM
resource "azurerm_virtual_machine_data_disk_attachment" "ad_data" {
  managed_disk_id    = azurerm_managed_disk.ad_data.id
  virtual_machine_id = azurerm_windows_virtual_machine.dc.id
  lun                = "10"
  caching            = "None"
}

# COMMENTED OUT: VM Extension for AD installation
# We'll handle AD installation manually with proper timing
# resource "azurerm_virtual_machine_extension" "initialize_and_configure_ad" {
#   name                 = "initialize-and-configure-ad"
#   virtual_machine_id   = azurerm_windows_virtual_machine.dc.id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.10"
#   depends_on          = [
#     azurerm_virtual_machine_data_disk_attachment.ad_data,
#     azurerm_key_vault_secret.ldap_bind_password
#   ]
#
#   settings = jsonencode({
#     "commandToExecute" = <<-EOF
#       powershell.exe -ExecutionPolicy Unrestricted -Command "
#         # Install AD Domain Services
#         Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
#         
#         # Install the domain
#         Import-Module ADDSDeployment
#         Install-ADDSForest -DomainName rule4.local -SafeModeAdministratorPassword (ConvertTo-SecureString '${random_password.dc_admin.result}' -AsPlainText -Force) -Force -NoRebootOnCompletion:$false
#         
#         # Wait for reboot and AD services to start
#         Start-Sleep -Seconds 60
#         
#         # Create Django LDAP bind user and test accounts
#         try {
#           Import-Module ActiveDirectory
#           
#           # Create Django service account for LDAP binding
#           New-ADUser -Name 'django' -UserPrincipalName 'django@rule4.local' -SamAccountName 'django' -AccountPassword (ConvertTo-SecureString '${azurerm_key_vault_secret.ldap_bind_password.value}' -AsPlainText -Force) -Enabled $true -PasswordNeverExpires $true -Description 'Django LDAP Bind Account'
#           
#           # Create Django groups for permissions
#           New-ADGroup -Name 'DjangoStaff' -GroupScope Global -GroupCategory Security -Description 'Django Staff Users'
#           New-ADGroup -Name 'DjangoAdmins' -GroupScope Global -GroupCategory Security -Description 'Django Admin Users'
#           
#           # Create test users for LDAP authentication testing
#           New-ADUser -Name 'testuser' -UserPrincipalName 'testuser@rule4.local' -SamAccountName 'testuser' -AccountPassword (ConvertTo-SecureString 'TestPass123!' -AsPlainText -Force) -Enabled $true -GivenName 'Test' -Surname 'User' -DisplayName 'Test User' -EmailAddress 'testuser@rule4.local'
#           
#           New-ADUser -Name 'adminuser' -UserPrincipalName 'adminuser@rule4.local' -SamAccountName 'adminuser' -AccountPassword (ConvertTo-SecureString 'AdminPass123!' -AsPlainText -Force) -Enabled $true -GivenName 'Admin' -Surname 'User' -DisplayName 'Admin User' -EmailAddress 'adminuser@rule4.local'
#           
#           # Add users to appropriate Django groups
#           Add-ADGroupMember -Identity 'DjangoStaff' -Members 'testuser'
#           Add-ADGroupMember -Identity 'DjangoAdmins' -Members 'adminuser'
#           Add-ADGroupMember -Identity 'DjangoStaff' -Members 'adminuser'
#           
#           Write-Output 'Django LDAP users and groups created successfully'
#         } catch {
#           Write-Output 'Error creating Django LDAP users: ' + $_.Exception.Message
#         }
#       "
#     EOF
#   })
# } 