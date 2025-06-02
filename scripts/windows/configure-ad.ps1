# Configure Active Directory
param (
    [Parameter(Mandatory=$true)]
    [string]$DomainName = "rule4.local",
    
    [Parameter(Mandatory=$true)]
    [string]$SafeModeAdminPassword = $env:DOMAIN_ADMIN_PASSWORD,
    
    [Parameter(Mandatory=$true)]
    [string]$FoxUserPassword = $env:FOX_USER_PASSWORD
)

# Install AD DS role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Configure AD DS
$domainName = "rule4.local"
$safeModePassword = ConvertTo-SecureString $SafeModeAdminPassword -AsPlainText -Force

Install-ADDSForest `
    -DomainName $domainName `
    -SafeModeAdministratorPassword $safeModePassword `
    -InstallDns `
    -Force

# Create test user
$userPassword = ConvertTo-SecureString $FoxUserPassword -AsPlainText -Force
New-ADUser -Name "fox" -AccountPassword $userPassword -Enabled $true -PasswordNeverExpires $true
Add-ADGroupMember -Identity "Domain Admins" -Members "fox"

# Enable LDAPS
$cert = New-SelfSignedCertificate `
    -DnsName $domainName `
    -CertStoreLocation "cert:\LocalMachine\My" `
    -KeySpec KeyExchange

# Export certificate for Django
$certPath = "C:\ldaps.cer"
Export-Certificate -Cert $cert -FilePath $certPath -Type CERT

# Restart AD DS service
Restart-Service -Name NTDS

# Wait for AD DS to be ready
Start-Sleep -Seconds 60

# Create Organizational Units
New-ADOrganizationalUnit -Name "Rule4" -Path "DC=rule4,DC=local"
New-ADOrganizationalUnit -Name "Clients" -Path "OU=Rule4,DC=rule4,DC=local"
New-ADOrganizationalUnit -Name "Service Accounts" -Path "OU=Rule4,DC=rule4,DC=local"

# Configure DNS for LDAPS
Add-DnsServerResourceRecordA -Name "ldaps" -ZoneName "rule4.local" -IPv4Address "10.0.1.10" 