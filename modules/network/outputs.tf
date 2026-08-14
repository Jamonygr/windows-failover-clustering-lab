output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.this.name
}

output "identity_subnet_id" {
  description = "Identity subnet ID"
  value       = azurerm_subnet.identity.id
}

output "cluster_subnet_id" {
  description = "Cluster subnet ID"
  value       = azurerm_subnet.cluster.id
}
