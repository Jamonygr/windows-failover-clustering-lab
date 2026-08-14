# =============================================================================
# TERRAFORM BACKEND CONFIGURATION
# =============================================================================
# State stays local by default: this lab is applied and destroyed from your
# workstation, and CI never authenticates to Azure. If you want remote state,
# uncomment the azurerm backend and supply -backend-config values.
# =============================================================================

# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-terraform-state"
#     storage_account_name = "stterraformstate"
#     container_name       = "tfstate"
#     key                  = "wsfc-lab.terraform.tfstate"
#   }
# }
