# =============================================================================
# WITNESS STORAGE MODULE - Cloud Witness quorum blob account
# =============================================================================
# WSFC Cloud Witness authenticates with the storage account key (SE-01) and
# creates its own msft-cloud-witness container. Network access is limited to
# the cluster subnet's service endpoint plus optional admin IPs (SE-03).
# =============================================================================

resource "azurerm_storage_account" "witness" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  account_kind                     = "StorageV2"
  access_tier                      = "Hot"
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  shared_access_key_enabled        = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  public_network_access_enabled    = true

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ips
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}
