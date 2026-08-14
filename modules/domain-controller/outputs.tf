output "vm_id" {
  description = "Domain controller VM ID"
  value       = azurerm_windows_virtual_machine.dc.id
}

output "computer_name" {
  description = "Domain controller computer name"
  value       = var.computer_name
}

output "private_ip" {
  description = "Domain controller private IP"
  value       = var.ip_address
}

output "ready_id" {
  description = "Marker that flips once AD DS is promoted and warmed up; gate domain joins on this"
  value       = time_sleep.ad_ready.id
}
