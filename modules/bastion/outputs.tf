output "id" {
  description = "Bastion host ID"
  value       = azurerm_bastion_host.developer.id
}

output "name" {
  description = "Bastion host name"
  value       = azurerm_bastion_host.developer.name
}
