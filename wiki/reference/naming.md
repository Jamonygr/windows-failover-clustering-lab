# Naming conventions

Names follow the Cloud Adoption Framework style used across my labs:
`<type>-<project>-<environment>-<location_short>`, built centrally in
[modules/naming](../../modules/naming/main.tf) so every consumer agrees.

## Location short codes

Common codes from the module's map (fallback: first 4 characters):

| Region | Code |
|--------|------|
| westus2 | wus2 |
| eastus2 | eus2 |
| westeurope | weu |
| northeurope | neu |
| uksouth | uks |
| swedencentral | swc |
| australiaeast | aue |

## Names produced (lab profile, westus2)

| Resource | Name |
|----------|------|
| Resource group | `rg-wsfc-lab-wus2` |
| VNet | `vnet-wsfc-lab-wus2` |
| Subnets | `snet-identity`, `snet-cluster` |
| NSGs | `nsg-identity-wsfc-lab-wus2`, `nsg-cluster-wsfc-lab-wus2` |
| Availability set | `avail-wsfc-lab-wus2` |
| DC VM / computer | `vm-dc01-wsfc-lab-wus2` / `dc01` |
| Node VMs / computers | `vm-node01-…`, `vm-node02-…` / `node01`, `node02` |
| Shared disk | `disk-shared-wsfc-lab-wus2` |
| Witness storage | `stwsfcwitlab<suffix>` (24-char cap, hyphens stripped) |
| Load balancer | `lbi-wsfc-lab-wus2` |
| Bastion | `bas-wsfc-lab-wus2` |
| Log Analytics | `log-wsfc-lab-wus2` |

## Why two names per VM

Azure resource names can be long and descriptive; **Windows computer names
cannot exceed 15 characters** (NetBIOS). The cluster, AD, and the drill
scripts all key on the short computer names (`node01`, `node02`), while the
portal shows the descriptive VM names. The drill scripts map between the two
with the `vm-(node\d+)-` prefix convention — keep it if you rename anything.

## Cluster object names

- `wsfc01` — cluster name object (CNO), created in AD by `New-Cluster`.
- `fs01` — virtual computer object (VCO) for the file server role; also its
  DNS A record (`fs01.wsfclab.local` -> `10.80.2.100`).
- `fs-data-disk` — the clustered Physical Disk resource (renamed from
  `Cluster Disk 1` so drill output reads well).

## Tags

Every resource carries `Project`, `Environment`, `ManagedBy = terraform`,
`Repository`, `Owner`, plus anything you add via `var.tags`.

## Related pages

- [Variables reference](variables.md)
- [Architecture overview](../architecture/overview.md)
