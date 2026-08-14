# =============================================================================
# LOAD BALANCER MODULE - internal Standard LB fronting the cluster role IP
# =============================================================================
# The frontend IP equals the clustered file server role IP. Azure only routes
# to whichever node answers the health probe, which the cluster IP resource
# does once scripts/vm/set-ilb-probe.ps1 has run. The HA-ports rule with
# floating IP forwards SMB (and everything else) to the role owner unchanged.
# =============================================================================

resource "azurerm_lb" "internal" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                          = "fe-fsrole"
    subnet_id                     = var.subnet_id
    private_ip_address            = var.frontend_ip
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_backend_address_pool" "nodes" {
  name            = "bepool-nodes"
  loadbalancer_id = azurerm_lb.internal.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nodes" {
  for_each = var.node_nic_ids

  network_interface_id    = each.value
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.nodes.id
}

resource "azurerm_lb_probe" "cluster_ip" {
  name                = "probe-cluster-ip"
  loadbalancer_id     = azurerm_lb.internal.id
  protocol            = "Tcp"
  port                = var.probe_port
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "ha_ports" {
  name                           = "rule-ha-ports"
  loadbalancer_id                = azurerm_lb.internal.id
  frontend_ip_configuration_name = "fe-fsrole"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nodes.id]
  probe_id                       = azurerm_lb_probe.cluster_ip.id
  floating_ip_enabled            = true
  idle_timeout_in_minutes        = 30
}
