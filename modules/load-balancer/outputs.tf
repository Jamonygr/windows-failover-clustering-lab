output "id" {
  description = "Load balancer ID"
  value       = azurerm_lb.internal.id
}

output "frontend_ip" {
  description = "Frontend private IP"
  value       = var.frontend_ip
}
