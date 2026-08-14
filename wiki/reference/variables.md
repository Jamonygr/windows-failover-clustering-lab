# Variables reference

Curated view of the inputs you actually touch. The generated
[TERRAFORM.md](../../TERRAFORM.md) is the canonical, complete list.

## Context

| Variable | Default | Notes |
|----------|---------|-------|
| `subscription_id` | — | Required GUID |
| `project` | `wsfc` | 2-8 lowercase alphanumerics, drives names |
| `environment` | `lab` | `cheap-lab` or `lab`; matches `environments/*.tfvars` |
| `location` | `westus2` | Pick a Bastion-Developer region if `deploy_bastion` |
| `owner` | `""` | Tag value |

## Credentials

| Variable | Default | Notes |
|----------|---------|-------|
| `admin_username` | `azureadmin` | Local + domain admin on all VMs |
| `admin_password` | `null` | Null = Terraform generates; `terraform output -raw admin_password` |
| `safe_mode_password` | `null` | DSRM password; null = generated |

Set real values only via `TF_VAR_*` environment variables, never in tfvars.

## Identity and cluster

| Variable | Default | Notes |
|----------|---------|-------|
| `domain_name` | `wsfclab.local` | Forest root FQDN |
| `domain_netbios_name` | `WSFCLAB` | Max 15 uppercase chars |
| `cluster_name` | `wsfc01` | DNN management point, NetBIOS-safe |
| `fs_role_name` | `fs01` | File server role and its AD/DNS name |
| `share_name` | `data` | SMB share on the clustered disk |

## Network

| Variable | Default |
|----------|---------|
| `vnet_address_space` | `["10.80.0.0/16"]` |
| `identity_subnet_prefix` | `10.80.1.0/24` |
| `cluster_subnet_prefix` | `10.80.2.0/24` |
| `dc_ip_address` | `10.80.1.4` |
| `node1_ip_address` / `node2_ip_address` | `10.80.2.4` / `10.80.2.5` |
| `fs_role_ip_address` | `10.80.2.100` (also the ILB frontend) |
| `allowed_witness_admin_ips` | `[]` (add your IP only if Terraform storage reads fail) |

## Shared disk

| Variable | Default | Notes |
|----------|---------|-------|
| `shared_disk_size_gb` | `32` | E4/P4 tier at default |
| `shared_disk_storage_account_type` | `StandardSSD_LRS` | Or `Premium_LRS` |
| `shared_disk_max_shares` | `2` | 2-3; the whole point of the lab |

Shared-disk rules the lab already enforces: data disk only, host caching
`None`, Basic (not dynamic) disk in-guest, LRS within one availability set.

## Feature flags

| Flag | Default | Cost when on |
|------|---------|--------------|
| `deploy_load_balancer` | `false` | ~$18/mo — SMB client access to the role IP |
| `deploy_bastion` | `false` | Free (Developer SKU) — browser RDP |
| `deploy_monitoring` | `false` | ~free — Log Analytics + availability alerts |
| `enable_auto_shutdown` | `false` | Saves money — daily VM stop |

## Related pages

- [Naming conventions](naming.md)
- [Cost guide](../cost.md)
