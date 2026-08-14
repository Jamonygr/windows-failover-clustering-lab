variable "name" {
  description = "Bastion host name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region (must support Bastion Developer SKU)"
  type        = string
}

variable "virtual_network_id" {
  description = "VNet the Developer SKU attaches to"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
