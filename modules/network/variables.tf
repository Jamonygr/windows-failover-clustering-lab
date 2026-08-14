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

variable "vnet_name" {
  description = "Virtual network name"
  type        = string
}

variable "address_space" {
  description = "VNet address space"
  type        = list(string)
}

variable "dns_servers" {
  description = "Custom DNS servers for the VNet (the domain controller)"
  type        = list(string)
}

variable "identity_subnet_name" {
  description = "Identity subnet name"
  type        = string
}

variable "identity_subnet_prefix" {
  description = "Identity subnet CIDR"
  type        = string
}

variable "cluster_subnet_name" {
  description = "Cluster subnet name"
  type        = string
}

variable "cluster_subnet_prefix" {
  description = "Cluster subnet CIDR"
  type        = string
}

variable "identity_nsg_name" {
  description = "Identity NSG name"
  type        = string
}

variable "cluster_nsg_name" {
  description = "Cluster NSG name"
  type        = string
}

variable "probe_port" {
  description = "ILB health probe port allowed from AzureLoadBalancer"
  type        = number
}
