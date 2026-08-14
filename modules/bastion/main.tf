# =============================================================================
# BASTION MODULE - Developer SKU (free browser RDP, no dedicated subnet,
# no public IP, region-limited; see wiki/troubleshooting.md)
# =============================================================================

resource "azurerm_bastion_host" "developer" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Developer"
  virtual_network_id  = var.virtual_network_id
  tags                = var.tags
}
