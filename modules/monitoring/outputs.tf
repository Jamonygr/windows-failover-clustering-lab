output "workspace_id" {
  description = "Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.this.id
}

output "action_group_id" {
  description = "Action group ID"
  value       = azurerm_monitor_action_group.alerts.id
}
