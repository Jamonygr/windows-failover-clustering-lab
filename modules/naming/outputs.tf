output "location_short" {
  description = "Short location code"
  value       = local.location_short
}

output "prefix" {
  description = "Standard name suffix segment: project-environment-location"
  value       = local.prefix
}

output "resource_group_name" {
  description = "Resource group name"
  value       = "rg-${local.prefix}"
}

output "vnet_name" {
  description = "Virtual network name"
  value       = "vnet-${local.prefix}"
}

output "identity_subnet_name" {
  description = "Identity subnet name"
  value       = "snet-identity"
}

output "cluster_subnet_name" {
  description = "Cluster subnet name"
  value       = "snet-cluster"
}

output "identity_nsg_name" {
  description = "Identity NSG name"
  value       = "nsg-identity-${local.prefix}"
}

output "cluster_nsg_name" {
  description = "Cluster NSG name"
  value       = "nsg-cluster-${local.prefix}"
}

output "availability_set_name" {
  description = "Availability set name"
  value       = "avail-${local.prefix}"
}

output "load_balancer_name" {
  description = "Internal load balancer name"
  value       = "lbi-${local.prefix}"
}

output "bastion_name" {
  description = "Bastion host name"
  value       = "bas-${local.prefix}"
}

output "log_analytics_name" {
  description = "Log Analytics workspace name"
  value       = "log-${local.prefix}"
}

output "action_group_name" {
  description = "Monitor action group name"
  value       = "ag-${local.prefix}"
}

output "shared_disk_name" {
  description = "Shared managed disk name"
  value       = "disk-shared-${local.prefix}"
}

output "witness_storage_account_name" {
  description = "Cloud Witness storage account name (24-char cap, no hyphens)"
  value       = substr("st${var.project}wit${local.environment_compact}${var.suffix}", 0, 24)
}

output "dc_vm_name" {
  description = "Domain controller Azure VM name"
  value       = "vm-dc01-${local.prefix}"
}

output "dc_computer_name" {
  description = "Domain controller Windows computer name"
  value       = "dc01"
}

output "node1_vm_name" {
  description = "Cluster node 1 Azure VM name"
  value       = "vm-node01-${local.prefix}"
}

output "node1_computer_name" {
  description = "Cluster node 1 Windows computer name"
  value       = "node01"
}

output "node2_vm_name" {
  description = "Cluster node 2 Azure VM name"
  value       = "vm-node02-${local.prefix}"
}

output "node2_computer_name" {
  description = "Cluster node 2 Windows computer name"
  value       = "node02"
}
