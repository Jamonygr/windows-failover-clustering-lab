# cheap-lab: minimum spend profile. Three B2s VMs, 32 GiB Standard SSD shared
# disk, no optional extras. Roughly $0.19/hour compute+storage; destroy or
# deallocate when idle.

environment = "cheap-lab"
location    = "westus2"

dc_vm_size                   = "Standard_B2s"
node_vm_size                 = "Standard_B2s"
os_disk_storage_account_type = "StandardSSD_LRS"
windows_server_sku           = "2025-datacenter-azure-edition"

shared_disk_size_gb              = 32
shared_disk_storage_account_type = "StandardSSD_LRS"
shared_disk_max_shares           = 2

deploy_load_balancer = false
deploy_bastion       = false
deploy_monitoring    = false
enable_auto_shutdown = false
