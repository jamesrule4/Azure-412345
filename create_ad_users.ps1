# Create LDAP Users for Django Authentication
# Run this script AFTER Active Directory is installed and the domain controller has rebooted

param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName
)

Write-Output "Creating Django LDAP users and groups..."

try {
    # Import Active Directory module
    Import-Module ActiveDirectory
    
    # Get LDAP bind password from Key Vault
    Write-Output "Retrieving LDAP bind password from Key Vault: $KeyVaultName"
    $ldapPassword = az keyvault secret show --vault-name $KeyVaultName --name ldap-bind-password --query value -o tsv
    
    if (-not $ldapPassword) {
        Write-Error "Failed to retrieve LDAP bind password from Key Vault"
        exit 1
    }
    
    # Create Django service account for LDAP binding
    Write-Output "Creating Django service account..."
    New-ADUser -Name 'django' `
               -UserPrincipalName 'django@rule4.local' `
               -SamAccountName 'django' `
               -AccountPassword (ConvertTo-SecureString $ldapPassword -AsPlainText -Force) `
               -Enabled $true `
               -PasswordNeverExpires $true `
               -Description 'Django LDAP Bind Account'
    
    # Create Django groups for permissions
    Write-Output "Creating Django groups..."
    New-ADGroup -Name 'DjangoStaff' -GroupScope Global -GroupCategory Security -Description 'Django Staff Users'
    New-ADGroup -Name 'DjangoAdmins' -GroupScope Global -GroupCategory Security -Description 'Django Admin Users'
    
    # Create test users for LDAP authentication testing
    Write-Output "Creating test users..."
    New-ADUser -Name 'testuser' `
               -UserPrincipalName 'testuser@rule4.local' `
               -SamAccountName 'testuser' `
               -AccountPassword (ConvertTo-SecureString 'TestPass123!' -AsPlainText -Force) `
               -Enabled $true `
               -GivenName 'Test' `
               -Surname 'User' `
               -DisplayName 'Test User' `
               -EmailAddress 'testuser@rule4.local'
    
    New-ADUser -Name 'adminuser' `
               -UserPrincipalName 'adminuser@rule4.local' `
               -SamAccountName 'adminuser' `
               -AccountPassword (ConvertTo-SecureString 'AdminPass123!' -AsPlainText -Force) `
               -Enabled $true `
               -GivenName 'Admin' `
               -Surname 'User' `
               -DisplayName 'Admin User' `
               -EmailAddress 'adminuser@rule4.local'
    
    # Add users to appropriate Django groups
    Write-Output "Adding users to groups..."
    Add-ADGroupMember -Identity 'DjangoStaff' -Members 'testuser'
    Add-ADGroupMember -Identity 'DjangoAdmins' -Members 'adminuser'
    Add-ADGroupMember -Identity 'DjangoStaff' -Members 'adminuser'
    
    Write-Output ""
    Write-Output "✅ Django LDAP users and groups created successfully!"
    Write-Output ""
    Write-Output "Created Users:"
    Write-Output "   django (service account) - Password from Key Vault"
    Write-Output "   testuser - Password: TestPass123!"
    Write-Output "   adminuser - Password: AdminPass123!"
    Write-Output ""
    Write-Output "Created Groups:"
    Write-Output "   DjangoStaff (contains: testuser, adminuser)"
    Write-Output "   DjangoAdmins (contains: adminuser)"
    
} catch {
    Write-Error "Error creating Django LDAP users: $($_.Exception.Message)"
    exit 1
} 