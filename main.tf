# =============================================================================
# WINDOWS FAILOVER CLUSTERING LAB - ORCHESTRATION
# Network -> Domain Controller -> Witness -> Cluster -> Optional extras
# =============================================================================

terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# -----------------------------------------------------------------------------
# Naming, suffix, and generated secrets
# -----------------------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "random_password" "admin" {
  count = var.admin_password == null ? 1 : 0

  length      = 20
  min_lower   = 2
  min_upper   = 2
  min_numeric = 2
  min_special = 1
  # Avoid characters that complicate PowerShell parameter transit
  override_special = "!@#%^*-_=+"
}

resource "random_password" "safe_mode" {
  count = var.safe_mode_password == null ? 1 : 0

  length           = 20
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 1
  override_special = "!@#%^*-_=+"
}

module "naming" {
  source = "./modules/naming"

  project     = var.project
  environment = var.environment
  location    = var.location
  suffix      = random_string.suffix.result
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# -----------------------------------------------------------------------------
# Network (VNet DNS points at the DC; cluster subnet carries the storage
# service endpoint because new VNets have no default outbound internet)
# -----------------------------------------------------------------------------

module "network" {
  source = "./modules/network"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  vnet_name              = module.naming.vnet_name
  address_space          = var.vnet_address_space
  identity_subnet_name   = module.naming.identity_subnet_name
  identity_subnet_prefix = var.identity_subnet_prefix
  cluster_subnet_name    = module.naming.cluster_subnet_name
  cluster_subnet_prefix  = var.cluster_subnet_prefix
  identity_nsg_name      = module.naming.identity_nsg_name
  cluster_nsg_name       = module.naming.cluster_nsg_name
  dns_servers            = [var.dc_ip_address]
  probe_port             = var.probe_port
}

# -----------------------------------------------------------------------------
# Cloud Witness storage (key auth is a WSFC protocol requirement, SE-01)
# -----------------------------------------------------------------------------

module "witness_storage" {
  source = "./modules/witness-storage"

  name                = module.naming.witness_storage_account_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  allowed_subnet_ids = [module.network.cluster_subnet_id]
  allowed_ips        = var.allowed_witness_admin_ips
}

# -----------------------------------------------------------------------------
# Domain controller (forest promotion via run command; reboots out-of-band)
# -----------------------------------------------------------------------------

module "domain_controller" {
  source = "./modules/domain-controller"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  vm_name                      = module.naming.dc_vm_name
  computer_name                = module.naming.dc_computer_name
  vm_size                      = var.dc_vm_size
  subnet_id                    = module.network.identity_subnet_id
  ip_address                   = var.dc_ip_address
  admin_username               = var.admin_username
  admin_password               = local.admin_password
  safe_mode_password           = local.safe_mode_password
  os_disk_storage_account_type = var.os_disk_storage_account_type
  windows_server_sku           = var.windows_server_sku
  domain_name                  = var.domain_name
  domain_netbios_name          = var.domain_netbios_name
  forest_script_content        = local.forest_script
}

# -----------------------------------------------------------------------------
# Cluster: two WS2025 nodes, shared disk, cloud witness, file server role.
# Node VMs build in parallel with the DC; only the domain-join extensions
# gate on the DC-ready marker.
# -----------------------------------------------------------------------------

module "cluster" {
  source = "./modules/cluster"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  availability_set_name = module.naming.availability_set_name
  subnet_id             = module.network.cluster_subnet_id
  vm_size               = var.node_vm_size

  node1_vm_name       = module.naming.node1_vm_name
  node1_computer_name = module.naming.node1_computer_name
  node1_ip_address    = var.node1_ip_address
  node2_vm_name       = module.naming.node2_vm_name
  node2_computer_name = module.naming.node2_computer_name
  node2_ip_address    = var.node2_ip_address

  admin_username               = var.admin_username
  admin_password               = local.admin_password
  os_disk_storage_account_type = var.os_disk_storage_account_type
  windows_server_sku           = var.windows_server_sku

  domain_name         = var.domain_name
  domain_netbios_name = var.domain_netbios_name
  dc_ready            = module.domain_controller.ready_id

  shared_disk_name                 = module.naming.shared_disk_name
  shared_disk_size_gb              = var.shared_disk_size_gb
  shared_disk_storage_account_type = var.shared_disk_storage_account_type
  shared_disk_max_shares           = var.shared_disk_max_shares

  cluster_name       = var.cluster_name
  fs_role_name       = var.fs_role_name
  fs_role_ip_address = var.fs_role_ip_address
  share_name         = var.share_name

  witness_storage_account_name = module.witness_storage.name
  witness_storage_account_key  = module.witness_storage.primary_access_key

  features_script_content  = local.features_script
  configure_script_content = local.configure_script
}

# -----------------------------------------------------------------------------
# Optional: internal load balancer for SMB client access to the role IP
# -----------------------------------------------------------------------------

module "load_balancer" {
  count  = var.deploy_load_balancer ? 1 : 0
  source = "./modules/load-balancer"

  name                = module.naming.load_balancer_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  subnet_id    = module.network.cluster_subnet_id
  frontend_ip  = var.fs_role_ip_address
  probe_port   = var.probe_port
  node_nic_ids = module.cluster.node_nic_ids
}

# Runs at the root to avoid a cluster <-> load balancer module cycle: the
# cluster IP resource only answers the probe after this is configured.
resource "azurerm_virtual_machine_run_command" "ilb_probe" {
  count = var.deploy_load_balancer ? 1 : 0

  name               = "rc-set-ilb-probe"
  location           = azurerm_resource_group.main.location
  virtual_machine_id = module.cluster.node1_vm_id

  source {
    script = local.probe_script
  }

  parameter {
    name  = "FsRoleName"
    value = var.fs_role_name
  }

  parameter {
    name  = "FsRoleIp"
    value = var.fs_role_ip_address
  }

  parameter {
    name  = "ProbePort"
    value = tostring(var.probe_port)
  }

  depends_on = [module.cluster, module.load_balancer]

  timeouts {
    create = "30m"
  }
}

# -----------------------------------------------------------------------------
# Optional: Bastion Developer SKU (free browser RDP, no public VM IPs)
# -----------------------------------------------------------------------------

module "bastion" {
  count  = var.deploy_bastion ? 1 : 0
  source = "./modules/bastion"

  name                = module.naming.bastion_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  virtual_network_id  = module.network.vnet_id
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Optional: monitoring and auto-shutdown
# -----------------------------------------------------------------------------

module "monitoring" {
  count  = var.deploy_monitoring ? 1 : 0
  source = "./modules/monitoring"

  workspace_name      = module.naming.log_analytics_name
  action_group_name   = module.naming.action_group_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  retention_in_days     = var.log_retention_days
  alert_email_receivers = var.alert_email_receivers
  vm_ids                = local.all_vm_ids
}

module "auto_shutdown" {
  count  = var.enable_auto_shutdown ? 1 : 0
  source = "./modules/auto-shutdown"

  location            = azurerm_resource_group.main.location
  vm_ids              = local.all_vm_ids
  daily_shutdown_time = var.auto_shutdown_time
  timezone            = var.auto_shutdown_timezone
  tags                = local.common_tags
}
