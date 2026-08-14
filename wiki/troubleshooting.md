# Troubleshooting

## Where the evidence lives

| Where | What |
|-------|------|
| `C:\ProgramData\wsfclab\logs\` on each VM | Transcripts: `new-forest.log`, `install-cluster-features.log`, `configure-cluster-outer.log`, `configure-cluster-inner.log`, `set-ilb-probe.log` |
| `C:\ProgramData\wsfclab\configure-result.json` on node01 | Success/message from the cluster build task |
| `az vm run-command invoke … --scripts "Get-Content C:\ProgramData\wsfclab\logs\<file> -Tail 80"` | Read any of the above without RDP |
| System event log, source `FailoverClustering` | Arbitration, quorum, and resource events |

## Apply-time issues

**`rc-new-forest` or `rc-cluster-features` succeeded but nothing happened.**
Managed run commands can report success even when the script fails, depending
on provider behavior. The scripts guard against this by making the *next*
stage check its prerequisites, so a silent failure surfaces one step later.
Read the transcript for the failing stage, fix, and re-apply — every script
is idempotent.

**`rc-configure-cluster` timed out.** Read
`configure-cluster-inner.log`. Common causes:

- Node02 never answered on 445 — check its domain-join extension status and
  that both nodes rebooted after feature install.
- `Set-ClusterQuorum` failed — DNS or firewall. Verify on node01:
  `Resolve-DnsName <witness>.blob.core.windows.net` (must resolve via dc01 ->
  168.63.129.16) and that the witness account still lists the cluster subnet
  in its firewall rules.
- Scheduled task never ran — the domain credential was wrong or the account
  is not yet replicated; confirm you can `Get-ADUser azureadmin` on dc01.

**Terraform cannot read the witness storage account from your workstation**
(data-plane 403 during plan/apply). Add your public IP to
`allowed_witness_admin_ips` and re-apply.

**Domain join extension failed.** Almost always DNS or timing: the VNet DNS
server is dc01, so if the forest promotion did not finish, joins fail. Wait
for/verify `rc-new-forest`, then `terraform apply` again. Increase the
module's `ad_ready_delay` if your DC is slow (B-series burst credits).

## Drill-time issues

**Failover drill: role stuck `Pending` on the survivor.** Standard SSD disks
can take a minute+ to online after a hard preempt. If it exceeds the timeout,
check the survivor's System log for disk arbitration errors.

**Quorum drill: cluster did NOT go down in phase 2.** You waited too long
between phases — dynamic quorum re-weighted the votes. Restore everything
(enable witness access, start node02), let the cluster settle to 3 votes,
and run the drill again without long pauses. See
[quorum and voting](architecture/quorum-and-voting.md).

**Witness stays Failed after restoring access.** DNS caches or blob
propagation: wait 1-2 minutes, then
`Start-ClusterResource 'Cloud Witness'`. Persistent failure usually means
the storage firewall no longer contains the cluster subnet rule.

## Platform quirks worth knowing

- **No outbound internet** on the VMs is by design (default outbound access
  retired for new VNets in Sept 2025). Consequences: Windows activation
  against KMS may stay pending (harmless in a short-lived lab), no Windows
  Update, no external downloads. The Azure agent channel (168.63.129.16) and
  the storage service endpoint carry everything the lab needs.
- **Bastion Developer SKU** is free but region-limited and slower than
  Standard; if `deploy_bastion` fails with a SKU/region error, switch region
  or deploy without it and use run-commands only.
- **Run commands while the cluster is down** keep working — the agent channel
  does not depend on the cluster service. That is what makes the quorum
  drill's force-repair possible without RDP.
- **Re-running `terraform apply`** is always safe: guest scripts exit 0 when
  their work is done; run-command resources only re-execute when their
  script content or parameters change.

## Escalation path

1. `./scripts/get-cluster-health.ps1` — the fastest full picture.
2. Tail the relevant transcript in `C:\ProgramData\wsfclab\logs`.
3. `Get-WinEvent -LogName System -MaxEvents 50` filtered to
   `FailoverClustering` via run-command.
4. Worst case: `terraform destroy` and re-apply — the lab is disposable by
   design (~35 minutes to rebuild).
