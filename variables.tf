# =============================================================================
# WINDOWS FAILOVER CLUSTERING LAB - INPUT VARIABLES
# =============================================================================

# -----------------------------------------------------------------------------
# Context
# -----------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription ID to deploy into"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "project" {
  description = "Short project code used in resource names"
  type        = string
  default     = "wsfc"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.project))
    error_message = "project must be 2-8 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment profile (matches environments/*.tfvars)"
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["cheap-lab", "lab"], var.environment)
    error_message = "environment must be one of: cheap-lab, lab."
  }
}

variable "location" {
  description = "Azure region. Keep VMs and the shared disk in one region; if you enable deploy_bastion, pick a region with Bastion Developer SKU support."
  type        = string
  default     = "westus2"
}

variable "owner" {
  description = "Owner tag value (email or handle)"
  type        = string
  default     = ""
}

variable "repository_url" {
  description = "Repository tag value"
  type        = string
  default     = "https://github.com/Jamonygr/windows-failover-clustering-lab"
}

variable "tags" {
  description = "Extra tags merged onto all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Credentials (never put real values in committed tfvars; use TF_VAR_* or
# leave null to let Terraform generate them)
# -----------------------------------------------------------------------------

variable "admin_username" {
  description = "Local and domain administrator username for all VMs"
  type        = string
  default     = "azureadmin"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{3,20}$", var.admin_username)) && !contains(["administrator", "admin", "root", "guest"], lower(var.admin_username))
    error_message = "admin_username must be 3-20 alphanumeric characters and not a reserved name."
  }
}

variable "admin_password" {
  description = "Administrator password for all VMs. Leave null to generate one (retrieve via `terraform output -raw admin_password`)."
  type        = string
  default     = null
  sensitive   = true
  nullable    = true

  validation {
    condition     = var.admin_password == null || can(regex("^.{12,123}$", var.admin_password))
    error_message = "admin_password must be 12-123 characters when set."
  }
}

variable "safe_mode_password" {
  description = "AD DS Directory Services Restore Mode password. Leave null to generate one."
  type        = string
  default     = null
  sensitive   = true
  nullable    = true

  validation {
    condition     = var.safe_mode_password == null || can(regex("^.{12,123}$", var.safe_mode_password))
    error_message = "safe_mode_password must be 12-123 characters when set."
  }
}

# -----------------------------------------------------------------------------
# Identity
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Active Directory forest root domain FQDN"
  type        = string
  default     = "wsfclab.local"

  validation {
    condition     = can(regex("^[a-z0-9-]+(\\.[a-z0-9-]+)+$", var.domain_name))
    error_message = "domain_name must be a lowercase FQDN such as wsfclab.local."
  }
}

variable "domain_netbios_name" {
  description = "NetBIOS name of the AD domain"
  type        = string
  default     = "WSFCLAB"

  validation {
    condition     = can(regex("^[A-Z0-9]{1,15}$", var.domain_netbios_name))
    error_message = "domain_netbios_name must be 1-15 uppercase alphanumeric characters."
  }
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.80.0.0/16"]
}

variable "identity_subnet_prefix" {
  description = "Identity subnet CIDR (domain controller)"
  type        = string
  default     = "10.80.1.0/24"
}

variable "cluster_subnet_prefix" {
  description = "Cluster subnet CIDR (nodes, file server role IP, optional ILB frontend)"
  type        = string
  default     = "10.80.2.0/24"
}

variable "dc_ip_address" {
  description = "Static private IP of the domain controller (also the VNet DNS server)"
  type        = string
  default     = "10.80.1.4"
}

variable "node1_ip_address" {
  description = "Static private IP of cluster node 1"
  type        = string
  default     = "10.80.2.4"
}

variable "node2_ip_address" {
  description = "Static private IP of cluster node 2"
  type        = string
  default     = "10.80.2.5"
}

variable "fs_role_ip_address" {
  description = "Static IP claimed by the clustered file server role (and used as the ILB frontend when deploy_load_balancer = true). Must be unused in the cluster subnet."
  type        = string
  default     = "10.80.2.100"
}

variable "allowed_witness_admin_ips" {
  description = "Optional public IPs (yours) allowed through the witness storage account firewall; needed only if Terraform reads of the account fail from your workstation"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Compute
# -----------------------------------------------------------------------------

variable "dc_vm_size" {
  description = "VM size for the domain controller"
  type        = string
  default     = "Standard_B2s"
}

variable "node_vm_size" {
  description = "VM size for the cluster nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "os_disk_storage_account_type" {
  description = "OS disk type for all VMs"
  type        = string
  default     = "StandardSSD_LRS"

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.os_disk_storage_account_type)
    error_message = "os_disk_storage_account_type must be Standard_LRS, StandardSSD_LRS, or Premium_LRS."
  }
}

variable "windows_server_sku" {
  description = "Windows Server 2025 image SKU (MicrosoftWindowsServer/WindowsServer)"
  type        = string
  default     = "2025-datacenter-azure-edition"

  validation {
    condition = contains([
      "2025-datacenter-azure-edition",
      "2025-datacenter-azure-edition-smalldisk",
      "2025-datacenter-g2",
      "2025-datacenter-smalldisk-g2",
    ], var.windows_server_sku)
    error_message = "windows_server_sku must be a Windows Server 2025 SKU."
  }
}

# -----------------------------------------------------------------------------
# Cluster
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Failover cluster name (Distributed Network Name management point)"
  type        = string
  default     = "wsfc01"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,14}$", var.cluster_name))
    error_message = "cluster_name must be a NetBIOS-safe name of 1-15 characters."
  }
}

variable "fs_role_name" {
  description = "Clustered file server role name"
  type        = string
  default     = "fs01"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,14}$", var.fs_role_name))
    error_message = "fs_role_name must be a NetBIOS-safe name of 1-15 characters."
  }
}

variable "share_name" {
  description = "SMB share name created on the clustered disk"
  type        = string
  default     = "data"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,19}$", var.share_name))
    error_message = "share_name must be 1-20 characters (alphanumeric or hyphen)."
  }
}

variable "shared_disk_size_gb" {
  description = "Size of the Azure Shared Disk in GiB (32 = E4/P4 tier, the cheap default)"
  type        = number
  default     = 32

  validation {
    condition     = var.shared_disk_size_gb >= 4 && var.shared_disk_size_gb <= 1024
    error_message = "shared_disk_size_gb must be between 4 and 1024 for this lab."
  }
}

variable "shared_disk_storage_account_type" {
  description = "Shared disk SKU. StandardSSD_LRS and Premium_LRS both allow maxShares up to 3 at lab sizes; host caching is disabled either way."
  type        = string
  default     = "StandardSSD_LRS"

  validation {
    condition     = contains(["StandardSSD_LRS", "Premium_LRS"], var.shared_disk_storage_account_type)
    error_message = "shared_disk_storage_account_type must be StandardSSD_LRS or Premium_LRS."
  }
}

variable "shared_disk_max_shares" {
  description = "maxShares on the shared disk (2 nodes need 2; 3 is the SKU ceiling at lab sizes)"
  type        = number
  default     = 2

  validation {
    condition     = var.shared_disk_max_shares >= 2 && var.shared_disk_max_shares <= 3
    error_message = "shared_disk_max_shares must be 2 or 3 (a shared disk needs >= 2; E/P tier disks below 512 GiB cap at 3)."
  }
}

variable "probe_port" {
  description = "Health probe port the cluster IP resource answers on when deploy_load_balancer = true"
  type        = number
  default     = 59999

  validation {
    condition     = var.probe_port >= 1024 && var.probe_port <= 65535
    error_message = "probe_port must be between 1024 and 65535."
  }
}

# -----------------------------------------------------------------------------
# Feature flags
# -----------------------------------------------------------------------------

variable "deploy_load_balancer" {
  description = "Deploy an internal Standard Load Balancer so SMB clients can reach the file server role IP (~$18/month)"
  type        = bool
  default     = false
}

variable "deploy_bastion" {
  description = "Deploy Azure Bastion (Developer SKU, free) for browser RDP to the VMs"
  type        = bool
  default     = false
}

variable "deploy_monitoring" {
  description = "Deploy Log Analytics plus VM availability metric alerts"
  type        = bool
  default     = false
}

variable "enable_auto_shutdown" {
  description = "Enable daily auto-shutdown schedules on all VMs"
  type        = bool
  default     = false
}

variable "auto_shutdown_time" {
  description = "Daily shutdown time (HHmm, 24h)"
  type        = string
  default     = "1900"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3])[0-5][0-9]$", var.auto_shutdown_time))
    error_message = "auto_shutdown_time must be HHmm, for example 1900."
  }
}

variable "auto_shutdown_timezone" {
  description = "Time zone for the auto-shutdown schedule"
  type        = string
  default     = "Pacific Standard Time"
}

variable "alert_email_receivers" {
  description = "Email receivers for the monitoring action group"
  type = list(object({
    name          = string
    email_address = string
  }))
  default = []
}

variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}
