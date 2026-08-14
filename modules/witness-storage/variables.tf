variable "name" {
  description = "Storage account name (3-24 lowercase alphanumeric)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "name must be 3-24 lowercase alphanumeric characters."
  }
}

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

variable "allowed_subnet_ids" {
  description = "Subnet IDs granted access via Microsoft.Storage service endpoint"
  type        = list(string)
}

variable "allowed_ips" {
  description = "Optional public IPs allowed through the firewall (workstation access)"
  type        = list(string)
  default     = []
}
