# Public IP for Samba Domain Controller
resource "azurerm_public_ip" "samba_dc" {
  name                = "pip-samba-dc-${local.resource_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                = "Standard"
}

# Network interface for the Samba domain controller
resource "azurerm_network_interface" "samba_dc" {
  name                = "nic-samba-dc-${local.resource_suffix}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address           = local.domain_controller_ip
    public_ip_address_id         = azurerm_public_ip.samba_dc.id
  }
}

# Linux VM for Samba Domain Controller
resource "azurerm_linux_virtual_machine" "samba_dc" {
  name                = "vm-samba-dc-${local.resource_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
  admin_password      = random_password.dc_admin.result

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.samba_dc.id,
  ]

  # Enable both SSH key and password authentication
  admin_ssh_key {
    username   = "azureadmin"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Additional disk for Samba AD data
resource "azurerm_managed_disk" "samba_ad_data" {
  name                 = "disk-samba-dc-data-${local.resource_suffix}"
  location             = data.azurerm_resource_group.main.location
  resource_group_name  = data.azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

# Attach the data disk to the VM
resource "azurerm_virtual_machine_data_disk_attachment" "samba_ad_data" {
  managed_disk_id    = azurerm_managed_disk.samba_ad_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.samba_dc.id
  lun                = "10"
  caching            = "None"
}

# VM Extension for Samba AD DC installation and configuration
resource "azurerm_virtual_machine_extension" "samba_ad_setup" {
  name                 = "samba-ad-setup"
  virtual_machine_id   = azurerm_linux_virtual_machine.samba_dc.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"
  depends_on          = [
    azurerm_virtual_machine_data_disk_attachment.samba_ad_data,
    azurerm_key_vault_secret.ldap_bind_password
  ]

  settings = jsonencode({
    commandToExecute = <<-EOF
      #!/bin/bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      
      # Logging function
      log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/samba-setup.log
      }
      
      log "Starting Samba AD DC setup"
      
      # Update system
      log "Updating system packages..."
      apt-get update && apt-get upgrade -y
      
      # Set hostname and domain configuration
      log "Configuring hostname and domain..."
      hostnamectl set-hostname dc1.rule4.local
      echo "127.0.0.1 localhost" > /etc/hosts
      echo "${local.domain_controller_ip} dc1.rule4.local dc1" >> /etc/hosts
      
      # Install required packages for Samba AD DC
      log "Installing Samba AD DC packages..."
      apt-get install -y samba samba-dsdb-modules samba-vfs-modules winbind libnss-winbind libpam-winbind krb5-config krb5-user dnsutils
      
      # Configure Kerberos
      log "Configuring Kerberos..."
      cat > /etc/krb5.conf << 'KRB5_EOF'
[libdefaults]
    default_realm = RULE4.LOCAL
    dns_lookup_realm = false
    dns_lookup_kdc = true
    
[realms]
    RULE4.LOCAL = {
        kdc = dc1.rule4.local
        admin_server = dc1.rule4.local
    }
    
[domain_realm]
    .rule4.local = RULE4.LOCAL
    rule4.local = RULE4.LOCAL
KRB5_EOF
      
      # Stop and disable existing services
      log "Stopping existing services..."
      systemctl stop smbd nmbd winbind systemd-resolved || true
      systemctl disable smbd nmbd winbind systemd-resolved || true
      
      # Remove existing Samba configuration
      log "Removing existing Samba configuration..."
      rm -rf /etc/samba/smb.conf /var/lib/samba/* /var/cache/samba/* || true
      
      # Provision Samba AD DC
      log "Provisioning Samba AD DC..."
      samba-tool domain provision \
        --realm=RULE4.LOCAL \
        --domain=RULE4 \
        --adminpass='${random_password.dc_admin.result}' \
        --server-role=dc \
        --dns-backend=SAMBA_INTERNAL \
        --use-rfc2307
      
      # Configure DNS
      log "Configuring DNS..."
      echo "nameserver 127.0.0.1" > /etc/resolv.conf
      echo "search rule4.local" >> /etc/resolv.conf
      
      # Start Samba services
      log "Starting Samba services..."
      systemctl unmask samba-ad-dc
      systemctl enable samba-ad-dc
      systemctl start samba-ad-dc
      
      # Wait for services to be ready
      log "Waiting for Samba AD DC to be ready..."
      sleep 30
      
      # Create Django service account for LDAP binding
      log "Creating Django service account..."
      samba-tool user create django '${random_password.ldap_bind_password.result}' \
        --description="Django LDAP Bind Account"
      
      # Create Django groups for permissions
      log "Creating Django groups..."
      samba-tool group add DjangoStaff --description="Django Staff Users"
      samba-tool group add DjangoAdmins --description="Django Admin Users"
      
      # Create test users for LDAP authentication testing
      log "Creating test users..."
      samba-tool user create testuser 'TestPass123!' \
        --given-name="Test" \
        --surname="User" \
        --mail-address="testuser@rule4.local"
      
      samba-tool user create adminuser 'AdminPass123!' \
        --given-name="Admin" \
        --surname="User" \
        --mail-address="adminuser@rule4.local"
      
      # Add users to appropriate Django groups
      log "Adding users to groups..."
      samba-tool group addmembers DjangoStaff testuser
      samba-tool group addmembers DjangoAdmins adminuser
      samba-tool group addmembers DjangoStaff adminuser
      
      # Configure firewall
      log "Configuring firewall..."
      ufw allow 53/tcp
      ufw allow 53/udp
      ufw allow 88/tcp
      ufw allow 88/udp
      ufw allow 135/tcp
      ufw allow 139/tcp
      ufw allow 389/tcp
      ufw allow 389/udp
      ufw allow 445/tcp
      ufw allow 464/tcp
      ufw allow 464/udp
      ufw allow 636/tcp
      ufw allow 3268/tcp
      ufw allow 3269/tcp
      ufw allow 22/tcp
      ufw --force enable
      
      # Test Samba AD DC functionality
      log "Testing Samba AD DC functionality..."
      samba-tool domain level show
      samba-tool user list
      samba-tool group list
      
      # Test DNS resolution
      log "Testing DNS resolution..."
      nslookup rule4.local 127.0.0.1
      nslookup dc1.rule4.local 127.0.0.1
      
      # Test Kerberos authentication
      log "Testing Kerberos authentication..."
      echo '${random_password.dc_admin.result}' | kinit Administrator@RULE4.LOCAL
      klist
      
      # Create completion marker
      log "Samba AD DC setup completed successfully!"
      echo "Samba AD DC setup completed at $(date)" > /tmp/samba-setup-complete.txt
      
      # Restart services to ensure everything is running properly
      systemctl restart samba-ad-dc
      
      log "Samba AD DC is ready for LDAP authentication"
    EOF
  })
}

# Network Security Rules for Samba AD DC
resource "azurerm_network_security_rule" "allow_samba_dns" {
  name                        = "AllowSambaDNS"
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["53"]
  source_address_prefix       = local.subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "allow_samba_kerberos" {
  name                        = "AllowSambaKerberos"
  priority                    = 1020
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["88", "464"]
  source_address_prefix       = local.subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "allow_samba_ldap" {
  name                        = "AllowSambaLDAP"
  priority                    = 1030
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["389", "636", "3268", "3269"]
  source_address_prefix       = local.subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "allow_samba_smb" {
  name                        = "AllowSambaSMB"
  priority                    = 1040
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["135", "139", "445"]
  source_address_prefix       = local.subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "allow_samba_ssh" {
  name                        = "AllowSambaSSH"
  priority                    = 1050
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.admin_ip_address
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
} 