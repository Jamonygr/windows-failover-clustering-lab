# Variable validation contracts. Mock providers keep every run offline.

mock_provider "azurerm" {}
mock_provider "random" {}
mock_provider "time" {}

variables {
  subscription_id = "11111111-1111-4111-8111-111111111111"
}

run "environment_profile_is_validated" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}

run "shared_disk_needs_at_least_two_shares" {
  command = plan

  variables {
    shared_disk_max_shares = 1
  }

  expect_failures = [var.shared_disk_max_shares]
}

run "shared_disk_shares_capped_at_sku_limit" {
  command = plan

  variables {
    shared_disk_max_shares = 4
  }

  expect_failures = [var.shared_disk_max_shares]
}

run "shared_disk_type_is_validated" {
  command = plan

  variables {
    shared_disk_storage_account_type = "Standard_LRS"
  }

  expect_failures = [var.shared_disk_storage_account_type]
}

run "windows_server_sku_is_validated" {
  command = plan

  variables {
    windows_server_sku = "2022-datacenter-azure-edition"
  }

  expect_failures = [var.windows_server_sku]
}

run "domain_netbios_name_is_validated" {
  command = plan

  variables {
    domain_netbios_name = "WAYTOOLONGNETBIOSNAME"
  }

  expect_failures = [var.domain_netbios_name]
}

run "cluster_name_is_netbios_safe" {
  command = plan

  variables {
    cluster_name = "this-name-is-way-too-long"
  }

  expect_failures = [var.cluster_name]
}

run "probe_port_rejects_well_known_ports" {
  command = plan

  variables {
    probe_port = 445
  }

  expect_failures = [var.probe_port]
}

run "admin_username_rejects_reserved_names" {
  command = plan

  variables {
    admin_username = "administrator"
  }

  expect_failures = [var.admin_username]
}

run "admin_password_minimum_length" {
  command = plan

  variables {
    admin_password = "short"
  }

  expect_failures = [var.admin_password]
}

run "auto_shutdown_time_format" {
  command = plan

  variables {
    auto_shutdown_time = "7pm"
  }

  expect_failures = [var.auto_shutdown_time]
}

run "subscription_id_must_be_guid" {
  command = plan

  variables {
    subscription_id = "not-a-guid"
  }

  expect_failures = [var.subscription_id]
}
