output "node_vm_ids" {
  description = "Node VM IDs keyed by computer name"
  value = {
    (var.node1_computer_name) = azurerm_windows_virtual_machine.node["node1"].id
    (var.node2_computer_name) = azurerm_windows_virtual_machine.node["node2"].id
  }
}

output "node1_vm_id" {
  description = "Node 1 VM ID (target for follow-up run commands)"
  value       = azurerm_windows_virtual_machine.node["node1"].id
}

output "node_nic_ids" {
  description = "Node NIC IDs keyed by computer name (for load balancer backend association)"
  value = {
    (var.node1_computer_name) = azurerm_network_interface.node["node1"].id
    (var.node2_computer_name) = azurerm_network_interface.node["node2"].id
  }
}

output "shared_disk_id" {
  description = "Shared managed disk ID"
  value       = azurerm_managed_disk.shared.id
}

output "configure_run_command_id" {
  description = "ID of the cluster-configuration run command (completion marker)"
  value       = azurerm_virtual_machine_run_command.configure_cluster.id
}
