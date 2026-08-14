variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

variable "availability_set_name" {
  description = "Availability set name"
  type        = string
}

variable "subnet_id" {
  description = "Cluster subnet ID"
  type        = string
}

variable "vm_size" {
  description = "Node VM size"
  type        = string
}

variable "node1_vm_name" {
  description = "Node 1 Azure VM name"
  type        = string
}

variable "node1_computer_name" {
  description = "Node 1 Windows computer name"
  type        = string
}

variable "node1_ip_address" {
  description = "Node 1 static private IP"
  type        = string
}

variable "node2_vm_name" {
  description = "Node 2 Azure VM name"
  type        = string
}

variable "node2_computer_name" {
  description = "Node 2 Windows computer name"
  type        = string
}

variable "node2_ip_address" {
  description = "Node 2 static private IP"
  type        = string
}

variable "admin_username" {
  description = "Administrator username (local and domain)"
  type        = string
}

variable "admin_password" {
  description = "Administrator password"
  type        = string
  sensitive   = true
}

variable "os_disk_storage_account_type" {
  description = "OS disk storage type"
  type        = string
}

variable "windows_server_sku" {
  description = "Windows Server image SKU"
  type        = string
}

variable "domain_name" {
  description = "AD domain FQDN to join"
  type        = string
}

variable "domain_netbios_name" {
  description = "AD domain NetBIOS name"
  type        = string
}

variable "dc_ready" {
  description = "DC-ready marker from the domain-controller module; joins wait on it"
  type        = string
}

variable "shared_disk_name" {
  description = "Shared managed disk name"
  type        = string
}

variable "shared_disk_size_gb" {
  description = "Shared disk size in GiB"
  type        = number
}

variable "shared_disk_storage_account_type" {
  description = "Shared disk SKU"
  type        = string
}

variable "shared_disk_max_shares" {
  description = "maxShares on the shared disk"
  type        = number

  validation {
    condition     = var.shared_disk_max_shares >= 2
    error_message = "A shared disk for a failover cluster needs max_shares >= 2."
  }
}

variable "cluster_name" {
  description = "Failover cluster name"
  type        = string
}

variable "fs_role_name" {
  description = "File server role name"
  type        = string
}

variable "fs_role_ip_address" {
  description = "Static IP for the file server role"
  type        = string
}

variable "share_name" {
  description = "SMB share name"
  type        = string
}

variable "witness_storage_account_name" {
  description = "Cloud Witness storage account name"
  type        = string
}

variable "witness_storage_account_key" {
  description = "Cloud Witness storage account key"
  type        = string
  sensitive   = true
}

variable "features_script_content" {
  description = "PowerShell content of the cluster-features script"
  type        = string
}

variable "configure_script_content" {
  description = "PowerShell content of the cluster-configuration script"
  type        = string
}

variable "features_settle_delay" {
  description = "Wait after the feature-install reboot before cluster configuration"
  type        = string
  default     = "4m"
}
