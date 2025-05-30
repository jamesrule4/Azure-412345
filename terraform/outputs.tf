# Resource IDs and network info I'll need for future resources
output "domain_controller_id" {
  value = azurerm_windows_virtual_machine.dc.id
}

output "domain_controller_private_ip" {
  value = azurerm_network_interface.dc.private_ip_address
}

output "virtual_network_name" {
  value = azurerm_virtual_network.main.name
}

output "subnet_id" {
  value = azurerm_subnet.main.id
} 