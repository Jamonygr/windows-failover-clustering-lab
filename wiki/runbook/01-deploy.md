# Runbook 01: deploy the lab

## Before you apply

- [ ] `az login` and confirm the target subscription: `az account show -o table`.
- [ ] Copy a profile: `Copy-Item environments/cheap-lab.tfvars terraform.tfvars`.
- [ ] Set `subscription_id` (and optionally `owner`) in `terraform.tfvars`.
- [ ] Optional: set `TF_VAR_admin_password` / `TF_VAR_safe_mode_password` for
  the session, or let Terraform generate them.

## Apply

```powershell
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Expect **30-40 minutes**. What is happening while you wait:

| Phase | Approx. time | Signal |
|-------|--------------|--------|
| VNet, witness account, 3 VMs | 5-8 min | VMs visible in the portal |
| Forest promotion + reboot | 8-10 min | `rc-new-forest` completes, then a 6m settle |
| Domain joins (parallel) | 3-5 min | `domain-join` extensions succeed after reboots |
| Cluster features + reboot | 5-7 min | `rc-cluster-features` on both nodes, 4m settle |
| Shared disk attach + cluster build | 6-12 min | `rc-configure-cluster` on node01 |
| Optional ILB probe | 1-2 min | `rc-set-ilb-probe` (lab profile only) |

## Verify

```powershell
terraform output next_steps
./scripts/get-cluster-health.ps1 -ResourceGroup (terraform output -raw resource_group_name)
```

Healthy output shows:

- `NODES`: `node01` and `node02` both `state=Up`, `weight=1`.
- `RESOURCES`: `Cloud Witness` `Online`, `fs-data-disk` `Online`,
  the `fs01` IP and network name `Online`.
- `GROUPS`: `fs01` `Online` with an owner node.

If you enabled `deploy_bastion`, RDP from the portal (Bastion, Developer SKU)
with `azureadmin` and `terraform output -raw admin_password`, then run
`Get-ClusterNode` yourself.

If you enabled `deploy_load_balancer`, an in-VNet client (e.g. dc01) can map
the share:

```powershell
# from dc01 via Bastion
Test-NetConnection fs01.wsfclab.local -Port 445
Get-ChildItem \\fs01.wsfclab.local\data
```

## If something failed

Apply is safe to re-run: every guest script exits early when its work is
already done. See [troubleshooting](../troubleshooting.md) for the guest log
locations (`C:\ProgramData\wsfclab\logs`) and common failure modes.

## Next

- [Runbook 02: failover drill](02-failover-drill.md)
