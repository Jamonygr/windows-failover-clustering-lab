# Cost guide

Lab planning estimates for `westus2` (August 2026, pay-as-you-go, rounded).
Not pricing guarantees — check the Azure pricing calculator.

## cheap-lab profile

| Item | SKU | ~Hourly | ~Monthly (24/7) |
|------|-----|---------|-----------------|
| dc01 | Standard_B2s | $0.042 | $30 |
| node01 | Standard_B2s | $0.042 | $30 |
| node02 | Standard_B2s | $0.042 | $30 |
| 3x OS disk 127 GiB | StandardSSD_LRS (E10) | — | $29 |
| Shared data disk 32 GiB | StandardSSD_LRS (E4), maxShares 2 | — | $2.40 |
| Witness storage | Standard LRS, a few KB | — | <$0.10 |
| **Total** | | **~$0.17 + storage** | **~$120** |

A focused lab session (build, all three drills, destroy) is roughly **3-4
hours ≈ $1-2 total**. The monthly figure only matters if you leave it
running — don't.

## lab profile adds

| Item | SKU | ~Monthly (24/7) |
|------|-----|-----------------|
| Faster nodes | 2x D2s_v5 (~$0.096/hr each) + B2ms DC | +$110 vs cheap |
| Shared disk | P10 Premium 128 GiB | $20 |
| Internal Standard LB | 1 rule + probe | ~$18 |
| Bastion Developer | — | $0 |
| Log Analytics | PerGB2018, tiny ingestion | ~$0-3 |
| Auto-shutdown | — | $0 (saves money) |

## Cost controls built in

- `cheap-lab` defaults everywhere: B-series, Standard SSD, all flags off.
- `enable_auto_shutdown = true` deallocates VMs daily at `auto_shutdown_time`.
- Deallocated VMs stop compute billing; disks keep billing (~$31/mo total in
  cheap-lab). Cluster state survives deallocation.
- `terraform destroy` removes everything, witness account and key included.

## Shared-disk billing notes

- Standard/Premium SSD shared disks bill the disk tier **plus a per-mount
  multiplier** on Premium (why cheap-lab uses Standard SSD).
- maxShares does not change the disk's IOPS ceiling — an E4 stays ~500 IOPS
  whether one or two nodes mount it. Fine for drills; do not benchmark it.

## Habits

```powershell
# end of session, keeping the environment for tomorrow
az vm deallocate --ids $(az vm list -g <rg> --query "[].id" -o tsv)

# end of lab
terraform destroy
```
