# Quorum and voting

The point of this page: after reading it, the quorum drill's phase order will
feel obvious instead of arbitrary.

## The vote table

A two-node cluster with a witness has **three votes**:

| Voter | Vote |
|-------|------|
| node01 | 1 |
| node02 | 1 |
| Cloud Witness | 1 |

The cluster stays up while a **majority (2 of 3)** is reachable. Lose two
votes and the survivors stop the cluster service on purpose — stopping is the
protection against split-brain, where two halves each believe they own the
shared disk.

## What the Cloud Witness actually is

A tiny blob (`msft-cloud-witness` container) in the lab's storage account.
Each node talks HTTPS/443 to the blob endpoint using the storage account key
(that is why key auth stays enabled — see `SECURITY_EXCEPTIONS.md` SE-01).
In this lab that traffic flows through the cluster subnet's
`Microsoft.Storage` service endpoint, which is also why blocking the account
firewall is a perfect, reversible way to simulate witness loss.

## Dynamic quorum and dynamic witness (the trap)

Modern WSFC works hard to keep the cluster alive on any single surviving
vote, and it will silently defeat a naive quorum-loss drill:

- **Dynamic quorum**: as members fail, surviving nodes re-weight the
  remaining votes ("last man standing") so the cluster can shrink gracefully
  all the way down to one node.
- **Dynamic witness**: the witness only keeps its vote when the node-vote
  count is even; with an odd count its vote is zeroed to avoid ties.

How strong is this? **Live test results from this lab (WS2025, 2026-08)**:

1. With the witness blocked *first* and node02 hard-killed two minutes later,
   node01 survived — last-man-standing had already re-weighted the votes.
2. Even with `DynamicQuorum = 0` pinned before the failures, node01 *still*
   rode through witness + node loss with its cluster service running.
   Windows Server 2025 hardens two-node quorum handling beyond the classic
   majority math.

Great resilience, terrible demo. The drill therefore pins the votes
(`(Get-Cluster).DynamicQuorum = 0`) to give the classic majority-loss
behavior its best chance, and treats **both** outcomes as valid:

- **Quorum lost** (older behavior): the survivor stops its cluster service
  and the drill walks you through `Start-ClusterNode -FixQuorum`.
- **Cluster survives** (observed on WS2025): the drill reports the
  resiliency, skips the force step, and proceeds straight to repair.

The drill re-enables `DynamicQuorum` (the production default) on the way out.

## Forcing quorum

`Start-ClusterNode -FixQuorum` starts the cluster on the surviving node and
marks its copy of the cluster database **authoritative**. Every node that
rejoins later discards its own state and resyncs from the forced node. In the
lab that is exactly what you want; in production you would first ask what
changes might be thrown away. While forced, the cluster runs with
`ForceQuorum` semantics until a majority naturally returns.

Repair order in the drill:

1. `Start-ClusterNode -FixQuorum` on node01 — cluster up, one node.
2. Re-enable the witness account firewall — witness resource returns Online
   (the drill nudges it with `Start-ClusterResource` if needed).
3. `az vm start` node02 — it rejoins, resyncs, and the vote table returns to
   the full 3.

## Checking votes yourself

```powershell
./scripts/get-cluster-health.ps1 -ResourceGroup <rg>
```

`NODES` shows `weight=` per node (the *configured* vote). Inside a node,
`Get-ClusterNode | ft Name, State, NodeWeight, DynamicWeight` also shows the
*dynamic* weight — watch it change during the drills if you want to see
dynamic quorum working in real time.

## Related pages

- [Runbook: quorum repair](../runbook/03-quorum-repair.md)
- [Architecture overview](overview.md)
- Microsoft: [Understand cluster and pool quorum](https://learn.microsoft.com/azure/azure-local/concepts/quorum)
