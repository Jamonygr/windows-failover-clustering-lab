# lab: the full experience. Faster nodes, Premium shared disk, SMB access via
# internal load balancer, Bastion Developer RDP, monitoring, auto-shutdown.

environment = "lab"
location    = "westus2"

dc_vm_size                   = "Standard_B2ms"
node_vm_size                 = "Standard_D2s_v5"
os_disk_storage_account_type = "StandardSSD_LRS"
windows_server_sku           = "2025-datacenter-azure-edition"

shared_disk_size_gb              = 128
shared_disk_storage_account_type = "Premium_LRS"
shared_disk_max_shares           = 2

deploy_load_balancer = true
deploy_bastion       = true
deploy_monitoring    = true
log_retention_days   = 30

enable_auto_shutdown   = true
auto_shutdown_time     = "1900"
auto_shutdown_timezone = "Pacific Standard Time"

# alert_email_receivers = [
#   { name = "owner", email_address = "you@example.com" }
# ]
