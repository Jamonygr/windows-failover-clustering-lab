variable "name" {
  description = "Load balancer name"
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

variable "subnet_id" {
  description = "Cluster subnet ID for the internal frontend"
  type        = string
}

variable "frontend_ip" {
  description = "Frontend private IP; must equal the clustered role IP"
  type        = string
}

variable "probe_port" {
  description = "TCP health probe port answered by the cluster IP resource"
  type        = number
}

variable "node_nic_ids" {
  description = "Node NIC IDs keyed by computer name"
  type        = map(string)
}
