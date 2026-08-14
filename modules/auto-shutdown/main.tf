# =============================================================================
# AUTO-SHUTDOWN MODULE - daily dev/test shutdown schedules (cost safety)
# =============================================================================
# Deallocated VMs stop compute billing; disks and the witness account keep
# accruing pennies. Cluster state survives deallocation; quorum re-forms on
# start.
# =============================================================================

resource "azurerm_dev_test_global_vm_shutdown_schedule" "this" {
  for_each = var.vm_ids

  virtual_machine_id    = each.value
  location              = var.location
  enabled               = true
  daily_recurrence_time = var.daily_shutdown_time
  timezone              = var.timezone
  tags                  = var.tags

  notification_settings {
    enabled = false
  }
}
