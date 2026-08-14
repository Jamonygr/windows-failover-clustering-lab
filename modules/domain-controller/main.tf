# =============================================================================
# DOMAIN CONTROLLER MODULE - single WS2025 DC with AD DS forest
# =============================================================================
# The forest promotion run command schedules its own reboot (shutdown /r /t 30)
# and exits 0 first, because a reboot inside a run command fails the execution.
# time_sleep then covers the reboot plus AD service warm-up before any
# domain-join extension is allowed to start.
# =============================================================================

resource "azurerm_network_interface" "dc" {
  name                = "nic-${var.vm_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.ip_address
  }
}

resource "azurerm_windows_virtual_machine" "dc" {
  name                = var.vm_name
  computer_name       = var.computer_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  tags                = var.tags

  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.dc.id]

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

resource "azurerm_virtual_machine_run_command" "new_forest" {
  name               = "rc-new-forest"
  location           = var.location
  virtual_machine_id = azurerm_windows_virtual_machine.dc.id

  source {
    script = var.forest_script_content
  }

  parameter {
    name  = "DomainName"
    value = var.domain_name
  }

  parameter {
    name  = "DomainNetbiosName"
    value = var.domain_netbios_name
  }

  protected_parameter {
    name  = "SafeModePassword"
    value = var.safe_mode_password
  }

  timeouts {
    create = "30m"
    update = "30m"
  }
}

# Covers the scheduled reboot plus AD DS/DNS warm-up
resource "time_sleep" "ad_ready" {
  create_duration = var.ad_ready_delay

  triggers = {
    run_command = azurerm_virtual_machine_run_command.new_forest.id
  }
}
