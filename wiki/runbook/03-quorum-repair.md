# Runbook 03: quorum loss and repair

**Goal:** lose quorum for real (cluster service stops), force it back with an
authoritative restart, and restore the full vote table.

Read [quorum and voting](../architecture/quorum-and-voting.md) first — the
headline lesson is that WSFC's dynamic quorum is so effective that the drill
has to **pin the votes** (`DynamicQuorum = 0`) to demonstrate a majority
loss at all. A live test showed a single node surviving witness-plus-node
failure thanks to last-man-standing re-weighting.

## What the script does

[scripts/invoke-quorum-repair-drill.ps1](../../scripts/invoke-quorum-repair-drill.ps1)
prompts between phases (use `-Force` to skip prompts):

| Phase | Action | Cluster state after |
|-------|--------|---------------------|
| 0 | Baseline check | 2 nodes Up, witness Online (3/3 votes) |
| 1 | Pin votes (`DynamicQuorum = 0`), block witness (storage firewall), force a witness re-check | Witness Failed; cluster up on 2/3 fixed votes |
| 2 | Deallocate node02 | Outcome A: cluster service stops on node01 (classic quorum loss). Outcome B (observed on WS2025): the survivor rides through |
| 3 | Outcome A only: `Start-ClusterNode -FixQuorum` on node01 | Cluster up, forced, single node |
| 4 | Restore witness access, start node02, re-enable `DynamicQuorum` | 3/3 votes, defaults restored |

Both phase-2 outcomes end in `PASS`; the drill reports which one you got.
Outcome B is itself the lesson: WS2025 two-node clusters survive combined
witness + node loss that stopped earlier versions cold.

## Run it

```powershell
$rg      = terraform output -raw resource_group_name
$witness = terraform output -raw witness_storage_account_name
./scripts/invoke-quorum-repair-drill.ps1 -ResourceGroup $rg -WitnessAccountName $witness
```

Notes on what you will see:

- Phase 1 uses the management plane (`az storage account update`), so it
  works even though the blob endpoint itself is firewalled.
- Phase 2 can take a few minutes: the cluster retries witness arbitration
  before giving up. `ClusSvc: Stopped` on node01 is the drill's proof of a
  real quorum loss — the node chose stopping over risking split-brain.
- Phase 3's `-FixQuorum` makes node01's cluster database authoritative.
  When node02 rejoins in phase 4 it discards local state and resyncs.
- Run commands keep working on node01 throughout because the Azure agent
  channel is independent of the cluster service.

## Evidence to capture

- Phase transcripts, especially `node1 ClusSvc: Stopped` and the final
  `PASS: quorum broken, forced, and fully repaired`.
- `get-cluster-health.ps1` at the end: both nodes `Up`, `WITNESS=Online`.

## If the drill wedges

- Cluster service will not start even with `-FixQuorum`: check
  `Get-WinEvent -LogName System -MaxEvents 50` on node01 via run-command for
  FailoverClustering events; see [troubleshooting](../troubleshooting.md).
- Witness stays Failed after phase 4: give DNS a minute, then
  `Start-ClusterResource 'Cloud Witness'` (the script already attempts this).
- Aborted mid-drill: every phase is safe to re-run; the storage account and
  VMs can be restored manually (`--public-network-access Enabled`,
  `az vm start`).

## Next

- [Runbook 04: storage ownership](04-storage-ownership.md)
