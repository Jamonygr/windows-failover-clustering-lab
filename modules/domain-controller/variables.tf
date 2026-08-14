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

variable "vm_name" {
  description = "Azure VM resource name"
  type        = string
}

variable "computer_name" {
  description = "Windows computer name (max 15 characters)"
  type        = string
}

variable "vm_size" {
  description = "VM size"
  type        = string
}

variable "subnet_id" {
  description = "Identity subnet ID"
  type        = string
}

variable "ip_address" {
  description = "Static private IP address"
  type        = string
}

variable "admin_username" {
  description = "Administrator username"
  type        = string
}

variable "admin_password" {
  description = "Administrator password"
  type        = string
  sensitive   = true
}

variable "safe_mode_password" {
  description = "Directory Services Restore Mode password"
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
  description = "AD forest root domain FQDN"
  type        = string
}

variable "domain_netbios_name" {
  description = "AD domain NetBIOS name"
  type        = string
}

variable "forest_script_content" {
  description = "PowerShell content of the forest promotion script"
  type        = string
}

variable "ad_ready_delay" {
  description = "Wait after forest promotion (reboot + AD warm-up) before joins may start"
  type        = string
  default     = "6m"
}
