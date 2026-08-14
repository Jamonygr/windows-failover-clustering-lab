# Runbook 04: validate storage ownership

**Goal:** prove that exactly one node owns the shared disk at any moment
(SCSI persistent reservations), and that ownership — and the data — follows a
planned role move.

## What the script does

[scripts/test-storage-ownership.ps1](../../scripts/test-storage-ownership.ps1):

1. Confirms the `fs01` role and the `fs-data-disk` resource share an owner.
2. Shows the disk from **both** nodes: the owner has the `S:` volume mounted;
   the non-owner sees the same disk `Offline` with no volume — the platform
   enforces the reservation, not politeness.
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

- `DISK ... clustered=True status=Online offline=False` + `VOLUME S: present`
  — the owner's view.
- `DISK ... status=Offline` + `VOLUME S: not mounted` — the non-owner's view.
  This is Azure's shared-disk SCSI PR doing its job: both VMs *see* the LUN,
  only the reservation holder can use it.
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
