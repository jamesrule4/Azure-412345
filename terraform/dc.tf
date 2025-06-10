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

# AUTOMATED: VM Extension for AD installation
# This replaces manual AD setup to meet "push button" requirements
resource "azurerm_virtual_machine_extension" "initialize_and_configure_ad" {
  name                 = "initialize-and-configure-ad"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on          = [
    azurerm_virtual_machine_data_disk_attachment.ad_data,
    azurerm_key_vault_secret.ldap_bind_password
  ]

  settings = jsonencode({
    "commandToExecute" = <<-EOF
      powershell.exe -ExecutionPolicy Unrestricted -Command "
        # Wait for system to be fully ready
        Start-Sleep -Seconds 60
        
        # Install AD Domain Services
        Write-Output 'Installing AD Domain Services...'
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Restart:$false
        
        # Install the domain
        Write-Output 'Creating rule4.local domain...'
        Import-Module ADDSDeployment
        Install-ADDSForest -DomainName rule4.local -SafeModeAdministratorPassword (ConvertTo-SecureString '${random_password.dc_admin.result}' -AsPlainText -Force) -Force -NoRebootOnCompletion:$false
        
        # Schedule post-reboot script to create LDAP users
        Write-Output 'Scheduling post-reboot LDAP user creation...'
        \$postRebootScript = @'
# Wait for AD services to be fully ready after reboot
Start-Sleep -Seconds 120

try {
  Import-Module ActiveDirectory
  
  # Create Django service account for LDAP binding
  Write-Output \"Creating Django service account...\"
  New-ADUser -Name 'django' -UserPrincipalName 'django@rule4.local' -SamAccountName 'django' -AccountPassword (ConvertTo-SecureString '${random_password.ldap_bind_password.result}' -AsPlainText -Force) -Enabled \$true -PasswordNeverExpires \$true -Description 'Django LDAP Bind Account'
  
  # Create Django groups for permissions
  Write-Output \"Creating Django groups...\"
  New-ADGroup -Name 'DjangoStaff' -GroupScope Global -GroupCategory Security -Description 'Django Staff Users'
  New-ADGroup -Name 'DjangoAdmins' -GroupScope Global -GroupCategory Security -Description 'Django Admin Users'
  
  # Create test users for LDAP authentication testing
  Write-Output \"Creating test users...\"
  New-ADUser -Name 'testuser' -UserPrincipalName 'testuser@rule4.local' -SamAccountName 'testuser' -AccountPassword (ConvertTo-SecureString 'TestPass123!' -AsPlainText -Force) -Enabled \$true -GivenName 'Test' -Surname 'User' -DisplayName 'Test User' -EmailAddress 'testuser@rule4.local'
  
  New-ADUser -Name 'adminuser' -UserPrincipalName 'adminuser@rule4.local' -SamAccountName 'adminuser' -AccountPassword (ConvertTo-SecureString 'AdminPass123!' -AsPlainText -Force) -Enabled \$true -GivenName 'Admin' -Surname 'User' -DisplayName 'Admin User' -EmailAddress 'adminuser@rule4.local'
  
  # Add users to appropriate Django groups
  Write-Output \"Adding users to groups...\"
  Add-ADGroupMember -Identity 'DjangoStaff' -Members 'testuser'
  Add-ADGroupMember -Identity 'DjangoAdmins' -Members 'adminuser'
  Add-ADGroupMember -Identity 'DjangoStaff' -Members 'adminuser'
  
  Write-Output \"Django LDAP users and groups created successfully!\"
  
  # Create completion marker
  New-Item -Path 'C:\\ADSetupComplete.txt' -ItemType File -Value \"AD setup completed at \$(Get-Date)\"
  
} catch {
  Write-Output \"Error creating Django LDAP users: \$(\$_.Exception.Message)\"
  \$_ | Out-File -FilePath 'C:\\ADSetupError.txt'
}
'@

        # Save post-reboot script
        \$postRebootScript | Out-File -FilePath 'C:\\PostRebootADSetup.ps1' -Encoding UTF8
        
        # Create scheduled task to run after reboot
        \$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Unrestricted -File C:\\PostRebootADSetup.ps1'
        \$trigger = New-ScheduledTaskTrigger -AtStartup
        \$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        \$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName 'PostRebootADSetup' -Action \$action -Trigger \$trigger -Principal \$principal -Settings \$settings
        
        Write-Output 'AD installation initiated. System will reboot and complete LDAP user setup automatically.'
      "
    EOF
  })
} 