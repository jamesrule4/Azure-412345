# Resource IDs and network info
output "domain_controller_id" {
  value = azurerm_windows_virtual_machine.dc.id
}

output "domain_controller_private_ip" {
  value = azurerm_windows_virtual_machine.dc.private_ip_address
}

output "domain_controller_public_ip" {
  value = azurerm_public_ip.dc.ip_address
}

output "django_vm_public_ip" {
  value = azurerm_public_ip.django.ip_address
}

output "django_vm_private_ip" {
  value = azurerm_linux_virtual_machine.django.private_ip_address
}

output "virtual_network_name" {
  value = azurerm_virtual_network.main.name
}

output "subnet_id" {
  value = azurerm_subnet.main.id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_secrets" {
  value = {
    domain_admin_password = azurerm_key_vault_secret.domain_admin_password.name
    django_admin_password = azurerm_key_vault_secret.django_admin_password.name
    django_secret_key     = azurerm_key_vault_secret.django_secret_key.name
    ldap_bind_password    = azurerm_key_vault_secret.ldap_bind_password.name
  }
  description = "Names of the environment-specific secrets created in Key Vault"
} 