variable "workspace_name" {
  description = "Log Analytics workspace name"
  type        = string
}

variable "action_group_name" {
  description = "Action group name"
  type        = string
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

variable "retention_in_days" {
  description = "Workspace retention in days"
  type        = number
  default     = 30
}

variable "alert_email_receivers" {
  description = "Email receivers for the action group"
  type = list(object({
    name          = string
    email_address = string
  }))
  default = []
}

variable "vm_ids" {
  description = "VM IDs to alert on, keyed by computer name"
  type        = map(string)
}
