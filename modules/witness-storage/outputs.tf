output "id" {
  description = "Storage account ID"
  value       = azurerm_storage_account.witness.id
}

output "name" {
  description = "Storage account name"
  value       = azurerm_storage_account.witness.name
}

output "primary_access_key" {
  description = "Primary access key used by Set-ClusterQuorum -CloudWitness"
  value       = azurerm_storage_account.witness.primary_access_key
  sensitive   = true
}
