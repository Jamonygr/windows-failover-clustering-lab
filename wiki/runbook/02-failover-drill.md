# Runbook 02: failover drill (stop a node, prove role failover)

**Goal:** hard-stop the node that owns the `fs01` role and watch the cluster
restart the role on the survivor.

## What the script does

[scripts/invoke-failover-drill.ps1](../../scripts/invoke-failover-drill.ps1):

1. Asks the cluster which node owns `fs01`.
2. **Deallocates that VM** — a hard failure, closer to a hardware loss than a
   graceful `Stop-ClusterNode` (deallocate releases the host; nothing gets a
   chance to drain).
3. Polls the survivor until `fs01` reports `Online` with the survivor as
   owner, then prints `PASS`.
4. With `-Restore`, starts the stopped VM and waits for the node to rejoin.

## Run it

```powershell
$rg = terraform output -raw resource_group_name
./scripts/invoke-failover-drill.ps1 -ResourceGroup $rg -Restore
```

Expected timeline: the cluster detects the lost node within seconds, arbitration
completes, and the role is typically back `Online` on the survivor in **1-3
minutes** (Standard SSD lab disks are slow to online; Premium is quicker).

## What is happening underneath

- Quorum holds: 2 of 3 votes (survivor + Cloud Witness) — this is exactly why
  the witness exists in a two-node cluster.
- The surviving node **preempts the SCSI persistent reservation** on the
  shared disk, onlines it, replays NTFS metadata, and starts the role.
- The role's IP and network name come online on the survivor. With the ILB
  deployed, the probe flips within ~10 seconds and SMB clients reconnect
  (SMB transparent failover expectations are lab-grade here, not SOFS-grade).

## Evidence to capture

- The script's before/after owner lines and `PASS`.
- `./scripts/get-cluster-health.ps1` output showing the stopped node `Down`
  and the role `Online` on the survivor.
- Optional: portal metric `VmAvailabilityMetric` dip on the deallocated VM
  (alerts fire if `deploy_monitoring = true`).

## Clean up the drill

If you skipped `-Restore`:

```powershell
az vm start -g $rg -n <deallocated-vm-name>
```

The node rejoins automatically; the role stays where it is until you move it
(that is the next drill).

## Next

- [Runbook 03: quorum repair](03-quorum-repair.md)
