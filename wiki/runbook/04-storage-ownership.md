# Runbook 04: validate storage ownership

**Goal:** prove that exactly one node owns the shared disk at any moment
(SCSI persistent reservations), and that ownership — and the data — follows a
planned role move.

## What the script does

[scripts/test-storage-ownership.ps1](../../scripts/test-storage-ownership.ps1):

1. Confirms the `fs01` role and the `fs-data-disk` resource share an owner.
2. Shows the disk from **both** nodes: the cluster resource state plus the
   local mount table. Only the owner has `S:\` mounted locally — the
   non-owner cannot mount it because the platform enforces the SCSI
   reservation, not politeness. (Storage cmdlets like `Get-Disk` federate
   the *clustered* subsystem on cluster nodes and show the cluster-wide
   view from every node, which is why the script checks the local mount
   table instead.)
3. Writes `ownership-proof.txt` on the owner (through the clustered share
   path `S:\shares\data`).
4. `Move-ClusterGroup` to the other node — a *planned* failover: the disk is
   cleanly offlined, the reservation is released and re-acquired, and the
   role starts on the target.
5. Reads the proof file back on the new owner and shows the old owner no
   longer mounts the volume. Prints `PASS`.

## Run it

```powershell
$rg = terraform output -raw resource_group_name
./scripts/test-storage-ownership.ps1 -ResourceGroup $rg -MoveBack
```

## Reading the output

- `CLUSTER VIEW : fs-data-disk state=Online owner=<node>` — identical from
  both nodes; cluster resources are cluster-wide state.
- `LOCAL ACCESS : S:\ mounted on <node> = True/False` — differs per node;
  only the reservation holder mounts the filesystem. This is Azure's
  shared-disk SCSI PR doing its job: both VMs *see* the LUN, one uses it.
- The `read-back` line contains the text written by the *other* node — one
  disk, one filesystem, sequential ownership.

## Planned vs. unplanned moves

| | Planned (`Move-ClusterGroup`) | Unplanned (deallocate, runbook 02) |
|---|---|---|
| Reservation | Released by old owner, acquired by new | **Preempted** by survivor |
| Filesystem | Clean dismount | NTFS log replay on online |
| Downtime | Seconds | Tens of seconds to minutes |

## Evidence to capture

- Both disk views before and after the move.
- The proof-file write/read-back lines and `PASS`.

## Where to go next

- Re-run the [failover drill](02-failover-drill.md) with the ILB deployed and
  a client copying files — watch SMB pause and resume.
- Grow the story: convert the disk to a Cluster Shared Volume
  (`Add-ClusterSharedVolume`) and observe both nodes mounting
  `C:\ClusterStorage` simultaneously — then reason about why CSV changes the
  ownership model.
- Tear down: `terraform destroy` (the witness account and its key go with it).
