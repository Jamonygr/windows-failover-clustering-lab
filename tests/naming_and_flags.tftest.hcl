# Naming conventions and feature-flag wiring. Mock providers keep every run
# offline and plan-only.

mock_provider "azurerm" {}
mock_provider "random" {}
mock_provider "time" {}

variables {
  subscription_id = "11111111-1111-4111-8111-111111111111"
}

run "default_lab_names_follow_convention" {
  command = plan

  assert {
    condition     = azurerm_resource_group.main.name == "rg-wsfc-lab-wus2"
    error_message = "Resource group name should be rg-wsfc-lab-wus2 for the default lab profile."
  }

  assert {
    condition     = module.naming.vnet_name == "vnet-wsfc-lab-wus2"
    error_message = "VNet name should follow vnet-<project>-<environment>-<location_short>."
  }

  assert {
    condition     = module.naming.node1_computer_name == "node01" && module.naming.node2_computer_name == "node02"
    error_message = "Node computer names must stay node01/node02; drill scripts key on them."
  }

  assert {
    condition     = length(module.naming.dc_computer_name) <= 15 && length(module.naming.node1_computer_name) <= 15
    error_message = "Windows computer names must be NetBIOS-safe (15 characters or fewer)."
  }
}

run "witness_storage_name_is_valid_for_cheap_lab" {
  command = plan

  # Target the naming module directly so the suffix is a known value
  module {
    source = "./modules/naming"
  }

  variables {
    project     = "wsfc"
    environment = "cheap-lab"
    location    = "westus2"
    suffix      = "abc123"
  }

  assert {
    condition     = output.witness_storage_account_name == "stwsfcwitcheaplababc123"
    error_message = "Witness storage name must strip hyphens from the environment and append the suffix."
  }

  assert {
    condition     = can(regex("^[a-z0-9]{3,24}$", output.witness_storage_account_name))
    error_message = "Witness storage name must be 3-24 lowercase alphanumeric characters."
  }
}

run "optional_modules_stay_off_by_default" {
  command = plan

  assert {
    condition     = length(module.load_balancer) == 0
    error_message = "Load balancer must not deploy unless deploy_load_balancer = true."
  }

  assert {
    condition     = length(module.bastion) == 0
    error_message = "Bastion must not deploy unless deploy_bastion = true."
  }

  assert {
    condition     = length(module.monitoring) == 0
    error_message = "Monitoring must not deploy unless deploy_monitoring = true."
  }

  assert {
    condition     = length(module.auto_shutdown) == 0
    error_message = "Auto-shutdown must not deploy unless enable_auto_shutdown = true."
  }

  assert {
    condition     = length(azurerm_virtual_machine_run_command.ilb_probe) == 0
    error_message = "The ILB probe run command must track deploy_load_balancer."
  }
}

run "optional_modules_deploy_when_enabled" {
  command = plan

  variables {
    deploy_load_balancer = true
    deploy_bastion       = true
    deploy_monitoring    = true
    enable_auto_shutdown = true
  }

  assert {
    condition     = length(module.load_balancer) == 1 && length(module.bastion) == 1 && length(module.monitoring) == 1 && length(module.auto_shutdown) == 1
    error_message = "All optional modules must deploy when their flags are enabled."
  }

  assert {
    condition     = length(azurerm_virtual_machine_run_command.ilb_probe) == 1
    error_message = "The ILB probe run command must deploy with the load balancer."
  }
}
