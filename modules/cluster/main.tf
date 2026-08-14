# =============================================================================
# CLUSTER MODULE - two WS2025 nodes, Azure Shared Disk, WSFC build
# =============================================================================
# Sequence per node: VM -> domain join (JsonADDomainExtension, handles its own
# reboot) -> cluster features run command (schedules reboot, exits first) ->
# settle. Then the shared disk attaches (caching must be None on shared disks)
# and a single run command on node1 forms the cluster, sets the Cloud Witness,
# onlines the disk, and creates the file server role. That script relays the
# domain credential through a scheduled task because run commands execute as
# SYSTEM, which cannot create AD computer objects (SE-05).
# =============================================================================

locals {
  nodes = {
    node1 = {
      vm_name       = var.node1_vm_name
      computer_name = var.node1_computer_name
      ip_address    = var.node1_ip_address
    }
    node2 = {
      vm_name       = var.node2_vm_name
      computer_name = var.node2_computer_name
      ip_address    = var.node2_ip_address
    }
  }
}

# Gate that ties domain joins to the DC-ready marker without serializing
# VM creation behind the whole domain-controller module
resource "time_sleep" "dc_gate" {
  create_duration = "1s"

  triggers = {
    dc_ready = var.dc_ready
  }
}

resource "azurerm_availability_set" "cluster" {
  name                         = var.availability_set_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
  tags                         = var.tags
}

resource "azurerm_network_interface" "node" {
  for_each = local.nodes

  name                = "nic-${each.value.vm_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.ip_address
  }
}

resource "azurerm_windows_virtual_machine" "node" {
  for_each = local.nodes

  name                = each.value.vm_name
  computer_name       = each.value.computer_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  availability_set_id = azurerm_availability_set.cluster.id
  tags                = var.tags

  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.node[each.key].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_server_sku
    version   = "latest"
  }

  boot_diagnostics {}
}

resource "azurerm_virtual_machine_extension" "domain_join" {
  for_each = local.nodes

  name                       = "domain-join"
  virtual_machine_id         = azurerm_windows_virtual_machine.node[each.key].id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true
  tags                       = var.tags

  settings = jsonencode({
    Name    = var.domain_name
    User    = "${var.domain_netbios_name}\\${var.admin_username}"
    Restart = "true"
    Options = 3 # join + create computer account
  })

  protected_settings = jsonencode({
    Password = var.admin_password
  })

  depends_on = [time_sleep.dc_gate]

  timeouts {
    create = "30m"
  }
}

resource "time_sleep" "join_settle" {
  create_duration = "90s"

  triggers = {
    joins = join(",", [for k in sort(keys(local.nodes)) : azurerm_virtual_machine_extension.domain_join[k].id])
  }
}

resource "azurerm_virtual_machine_run_command" "features" {
  for_each = local.nodes

  name               = "rc-cluster-features"
  location           = var.location
  virtual_machine_id = azurerm_windows_virtual_machine.node[each.key].id

  source {
    script = var.features_script_content
  }

  depends_on = [time_sleep.join_settle]

  timeouts {
    create = "30m"
    update = "30m"
  }
}

# Covers the feature-install reboot on both nodes
resource "time_sleep" "features_settle" {
  create_duration = var.features_settle_delay

  triggers = {
    features = join(",", [for k in sort(keys(local.nodes)) : azurerm_virtual_machine_run_command.features[k].id])
  }
}

resource "azurerm_managed_disk" "shared" {
  name                = var.shared_disk_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  create_option        = "Empty"
  disk_size_gb         = var.shared_disk_size_gb
  storage_account_type = var.shared_disk_storage_account_type
  max_shares           = var.shared_disk_max_shares

  # Disk-export hardening; unrelated to in-VM SCSI access
  network_access_policy         = "DenyAll"
  public_network_access_enabled = false
}

# Shared disks require caching = None. Attach after the feature reboots so
# concurrent VM model updates cannot conflict.
resource "azurerm_virtual_machine_data_disk_attachment" "shared" {
  for_each = local.nodes

  managed_disk_id    = azurerm_managed_disk.shared.id
  virtual_machine_id = azurerm_windows_virtual_machine.node[each.key].id
  lun                = 0
  caching            = "None"

  depends_on = [time_sleep.features_settle]
}

resource "azurerm_virtual_machine_run_command" "configure_cluster" {
  name               = "rc-configure-cluster"
  location           = var.location
  virtual_machine_id = azurerm_windows_virtual_machine.node["node1"].id

  source {
    script = var.configure_script_content
  }

  parameter {
    name  = "ClusterName"
    value = var.cluster_name
  }

  parameter {
    name  = "NodeNames"
    value = "${var.node1_computer_name},${var.node2_computer_name}"
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
    name  = "ShareName"
    value = var.share_name
  }

  parameter {
    name  = "SharedDiskSizeGb"
    value = tostring(var.shared_disk_size_gb)
  }

  parameter {
    name  = "DomainNetbiosName"
    value = var.domain_netbios_name
  }

  parameter {
    name  = "AdminUsername"
    value = var.admin_username
  }

  parameter {
    name  = "WitnessAccountName"
    value = var.witness_storage_account_name
  }

  protected_parameter {
    name  = "AdminPassword"
    value = var.admin_password
  }

  protected_parameter {
    name  = "WitnessAccountKey"
    value = var.witness_storage_account_key
  }

  depends_on = [
    time_sleep.features_settle,
    azurerm_virtual_machine_data_disk_attachment.shared,
  ]

  timeouts {
    create = "45m"
    update = "45m"
  }
}
