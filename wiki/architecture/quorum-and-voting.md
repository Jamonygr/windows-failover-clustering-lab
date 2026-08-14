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

Modern WSFC does two clever things that will silently defeat a naive
"kill a node, then kill the witness" drill:

- **Dynamic quorum**: when a node goes down and the cluster *stabilizes*, the
  down node's vote is removed. Your 2-of-3 cluster becomes 1-of-1 or 2-of-2.
- **Dynamic witness**: the witness only keeps its vote when the node-vote
  count is even; with an odd count its vote is zeroed to avoid ties.

So if you deallocate node02 and wait, node02's vote disappears, the witness
vote re-weights, and blocking the witness afterwards does… nothing. The
cluster survives on node01 alone and the drill "fails" by succeeding.

**The drill therefore blocks the witness first** (cluster healthy, 2/3 votes,
nothing re-weights) **and then hard-kills node02** — two votes vanish before
dynamic quorum can stabilize, node01 sits at 1 of 3, and the cluster service
stops. That is a genuine quorum loss.

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
