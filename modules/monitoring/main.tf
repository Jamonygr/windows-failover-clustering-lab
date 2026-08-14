# =============================================================================
# MONITORING MODULE - Log Analytics + VM availability alerts
# =============================================================================
# Agentless on purpose: the VM availability platform metric flags node-down
# events (including deliberate drill deallocations) without AMA/DCR cost.
# =============================================================================

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "alerts" {
  name                = var.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = "wsfcalert"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_monitor_metric_alert" "vm_availability" {
  for_each = var.vm_ids

  name                = "alert-vm-availability-${each.key}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "VM ${each.key} availability dropped below 1 (stopped, deallocated, or unhealthy)."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}
