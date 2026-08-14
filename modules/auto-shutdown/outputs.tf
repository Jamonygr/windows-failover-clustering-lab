output "schedule_ids" {
  description = "Shutdown schedule IDs keyed by computer name"
  value       = { for k, v in azurerm_dev_test_global_vm_shutdown_schedule.this : k => v.id }
}
