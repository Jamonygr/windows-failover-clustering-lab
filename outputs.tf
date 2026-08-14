# =============================================================================
# WINDOWS FAILOVER CLUSTERING LAB - OUTPUTS
# =============================================================================

output "resource_group_name" {
  description = "Resource group containing the lab"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Deployment region"
  value       = azurerm_resource_group.main.location
}

output "vnet_id" {
  description = "Lab VNet ID"
  value       = module.network.vnet_id
}

output "dc_private_ip" {
  description = "Domain controller private IP (also the VNet DNS server)"
  value       = var.dc_ip_address
}

output "node_private_ips" {
  description = "Cluster node private IPs keyed by computer name"
  value = {
    (module.naming.node1_computer_name) = var.node1_ip_address
    (module.naming.node2_computer_name) = var.node2_ip_address
  }
}

output "node_vm_names" {
  description = "Azure VM names of the cluster nodes keyed by computer name (drill scripts need these)"
  value = {
    (module.naming.node1_computer_name) = module.naming.node1_vm_name
    (module.naming.node2_computer_name) = module.naming.node2_vm_name
  }
}

output "cluster_name" {
  description = "Failover cluster name (Distributed Network Name)"
  value       = var.cluster_name
}

output "fs_role_name" {
  description = "Clustered file server role name"
  value       = var.fs_role_name
}

output "fs_share_unc" {
  description = "UNC path of the clustered share (reachable in-VNet; needs deploy_load_balancer for the role IP to answer)"
  value       = "\\\\${var.fs_role_name}.${var.domain_name}\\${var.share_name}"
}

output "witness_storage_account_name" {
  description = "Cloud Witness storage account name"
  value       = module.witness_storage.name
}

output "load_balancer_frontend_ip" {
  description = "Internal load balancer frontend IP (null unless deploy_load_balancer)"
  value       = var.deploy_load_balancer ? module.load_balancer[0].frontend_ip : null
}

output "bastion_host_name" {
  description = "Bastion host name (null unless deploy_bastion)"
  value       = var.deploy_bastion ? module.bastion[0].name : null
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID (null unless deploy_monitoring)"
  value       = var.deploy_monitoring ? module.monitoring[0].workspace_id : null
}

output "admin_username" {
  description = "Administrator username for all VMs"
  value       = var.admin_username
}

output "admin_password" {
  description = "Administrator password (sensitive; see SECURITY_EXCEPTIONS.md SE-06). Retrieve with `terraform output -raw admin_password`."
  value       = local.admin_password
  sensitive   = true
}

output "next_steps" {
  description = "What to do after apply"
  value       = <<-EOT
    1. Health check : ./scripts/get-cluster-health.ps1 -ResourceGroup ${azurerm_resource_group.main.name}
    2. Failover     : ./scripts/invoke-failover-drill.ps1 -ResourceGroup ${azurerm_resource_group.main.name} -Restore
    3. Quorum       : ./scripts/invoke-quorum-repair-drill.ps1 -ResourceGroup ${azurerm_resource_group.main.name} -WitnessAccountName ${module.witness_storage.name}
    4. Storage      : ./scripts/test-storage-ownership.ps1 -ResourceGroup ${azurerm_resource_group.main.name}
    Wiki runbooks live in wiki/runbook/. Destroy with `terraform destroy` when finished.
  EOT
}
