# =============================================================================
# WINDOWS FAILOVER CLUSTERING LAB - LOCALS
# =============================================================================

locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = var.repository_url
      Owner       = var.owner
    },
    var.tags
  )

  # Fall back to generated secrets so no password ever needs to live in tfvars.
  admin_password     = var.admin_password != null ? var.admin_password : random_password.admin[0].result
  safe_mode_password = var.safe_mode_password != null ? var.safe_mode_password : random_password.safe_mode[0].result

  # Guest scripts are plain PowerShell with param() blocks; values arrive as
  # run-command parameters, so no templatefile() escaping is needed.
  forest_script    = file("${path.module}/scripts/vm/new-forest.ps1")
  features_script  = file("${path.module}/scripts/vm/install-cluster-features.ps1")
  configure_script = file("${path.module}/scripts/vm/configure-cluster.ps1")
  probe_script     = file("${path.module}/scripts/vm/set-ilb-probe.ps1")

  all_vm_ids = merge(
    module.cluster.node_vm_ids,
    { (module.domain_controller.computer_name) = module.domain_controller.vm_id }
  )
}
