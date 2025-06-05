param (
    [Parameter(Mandatory=$true)]
    [string]$DomainName = "rule4.local",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword = $env:DOMAIN_ADMIN_PASSWORD
)

# Check if AD DS is already installed
$addsFeature = Get-WindowsFeature -Name AD-Domain-Services
if (-not $addsFeature.Installed) {
    # Phase 1: Install AD DS role
    Write-Host "Installing AD DS role..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

    # Configure AD DS
    Write-Host "Configuring AD DS..."
    $password = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

    Install-ADDSForest `
        -DomainName $DomainName `
        -SafeModeAdministratorPassword $password `
        -InstallDns `
        -Force `
        -NoRebootOnCompletion

    # Signal that we need to reboot
    Write-Host "AD DS installation complete. Rebooting..."
    Restart-Computer -Force
} else {
    # Phase 2: Configure AD after reboot
    Write-Host "AD DS is installed. Configuring groups and users..."
    
    # Wait for AD Web Services to be ready
    $retryCount = 0
    $maxRetries = 30
    $retryInterval = 10

    while ($retryCount -lt $maxRetries) {
        try {
            Import-Module ActiveDirectory
            Get-ADDomain
            break
        } catch {
            Write-Host "AD Web Services not ready. Waiting..."
            Start-Sleep -Seconds $retryInterval
            $retryCount++
        }
    }

    if ($retryCount -eq $maxRetries) {
        Write-Error "AD Web Services did not become available in time"
        exit 1
    }

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

    # Create test user
    $password = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    New-ADUser -Name "fox" -AccountPassword $password -Enabled $true -PasswordNeverExpires $true
    Add-ADGroupMember -Identity "Domain Admins" -Members "fox"

    Write-Host "Setup complete!"
} 