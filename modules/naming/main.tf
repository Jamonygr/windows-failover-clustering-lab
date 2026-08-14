# =============================================================================
# NAMING MODULE - CAF-style names built from project, environment, location
# =============================================================================

locals {
  location_short_map = {
    westus2            = "wus2"
    westus             = "wus"
    westus3            = "wus3"
    eastus             = "eus"
    eastus2            = "eus2"
    centralus          = "cus"
    northcentralus     = "ncus"
    southcentralus     = "scus"
    canadacentral      = "cac"
    brazilsouth        = "brs"
    westeurope         = "weu"
    northeurope        = "neu"
    uksouth            = "uks"
    ukwest             = "ukw"
    swedencentral      = "swc"
    germanywestcentral = "gwc"
    francecentral      = "frc"
    switzerlandnorth   = "swn"
    norwayeast         = "noe"
    polandcentral      = "plc"
    italynorth         = "itn"
    spaincentral       = "spc"
    australiaeast      = "aue"
    southeastasia      = "sea"
    eastasia           = "ea"
    japaneast          = "jpe"
    koreacentral       = "krc"
    centralindia       = "cin"
    southafricanorth   = "san"
    uaenorth           = "uan"
    israelcentral      = "ilc"
    mexicocentral      = "mxc"
    newzealandnorth    = "nzn"
  }

  location_normalized = lower(replace(var.location, " ", ""))
  location_short      = lookup(local.location_short_map, local.location_normalized, substr(local.location_normalized, 0, 4))

  prefix = "${var.project}-${var.environment}-${local.location_short}"

  # Storage account names allow no hyphens and cap at 24 characters
  environment_compact = replace(var.environment, "-", "")
}
