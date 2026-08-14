variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

variable "vm_ids" {
  description = "VM IDs to schedule, keyed by computer name"
  type        = map(string)
}

variable "daily_shutdown_time" {
  description = "Daily shutdown time (HHmm, 24h)"
  type        = string
}

variable "timezone" {
  description = "Time zone for the schedule"
  type        = string
}
