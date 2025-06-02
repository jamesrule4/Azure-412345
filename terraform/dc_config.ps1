# Create Django-specific AD groups and test users
Import-Module ActiveDirectory

# Create the groups if they don't exist
$groups = @(
    @{
        Name = "DjangoStaff"
        Description = "Django staff members with elevated privileges"
    },
    @{
        Name = "DjangoAdmins"
        Description = "Django administrators with full access"
    }
)

foreach ($group in $groups) {
    try {
        if (-not (Get-ADGroup -Filter {Name -eq $group.Name})) {
            New-ADGroup -Name $group.Name `
                -GroupScope Global `
                -GroupCategory Security `
                -Description $group.Description
            Write-Output "Created group: $($group.Name)"
        } else {
            Write-Output "Group already exists: $($group.Name)"
        }
    } catch {
        $errorMessage = $PSItem.Exception.Message
        Write-Error "Error creating group $($group.Name): $errorMessage"
    }
}

# Configure Active Directory
param (
    [Parameter(Mandatory=$true)]
    [string]$DomainName = "rule4.local",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword = $env:DOMAIN_ADMIN_PASSWORD
)

# Install AD DS role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Configure AD DS
$password = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

Install-ADDSForest `
    -DomainName $DomainName `
    -SafeModeAdministratorPassword $password `
    -InstallDns `
    -Force

# Create test user
New-ADUser -Name "fox" -AccountPassword $password -Enabled $true -PasswordNeverExpires $true
Add-ADGroupMember -Identity "Domain Admins" -Members "fox"

Write-Host "Setup complete!" 