# Security exceptions

Accepted, lab-scoped risks with compensating controls. Do not copy these into
production without a separate risk review. Each entry has an owner-set review
date; expired entries block new changes until re-reviewed.

| ID | Finding | Scope | Rationale | Compensating control | Review by |
|----|---------|-------|-----------|----------------------|-----------|
| SE-01 | Storage account shared key auth enabled (`CKV2_AZURE_40`, `CKV2_AZURE_41`) | `modules/witness-storage` | WSFC Cloud Witness authenticates with the storage account key; Entra auth is not supported by the witness protocol. | Default-deny network rules; access limited to the cluster subnet service endpoint plus optional admin IPs; account holds only witness blob metadata; key rotated or account destroyed at teardown. | 2027-02-28 |
| SE-02 | VM extensions and run commands installed (`CKV_AZURE_50`) | `modules/domain-controller`, `modules/cluster`, root | Domain join, forest promotion, and cluster build are the purpose of the lab and run through the Azure agent channel. | Scripts are idempotent, transcript-logged on the VM, and carry secrets only in protected parameters. | 2027-02-28 |
| SE-03 | Witness endpoint is public with firewall, not Private Link (`CKV2_AZURE_33`, `CKV_AZURE_33`) | `modules/witness-storage` | Private Endpoint + DNS zone adds cost/complexity disproportionate to a disposable lab witness. | `default_action = "Deny"` with cluster-subnet service endpoint; TLS 1.2 minimum; HTTPS only. | 2027-02-28 |
| SE-04 | No CMK / encryption-at-host on VMs and shared disk (`CKV2_AZURE_1`, `CKV_AZURE_151`) | all compute | Azure Disk Encryption is unsupported on shared disks; encryption-at-host needs subscription feature registration. Platform SSE remains active. | Lab data is synthetic; platform-managed SSE encrypts all disks at rest. | 2027-02-28 |
| SE-05 | Domain credential and witness key pass through a scheduled task and a temporary JSON file on node01 | `scripts/vm/configure-cluster.ps1` | Cluster creation requires a domain identity; run commands execute as SYSTEM, so the script relays credentials to a scheduled task. | File ACL restricted to SYSTEM/Administrators, deleted in `finally`; task deleted after run; values never logged. | 2027-02-28 |
| SE-06 | `admin_password` exposed as a sensitive Terraform output | root `outputs.tf` | Passwords may be Terraform-generated and are otherwise unrecoverable for RDP. | Marked `sensitive`; retrievable only via explicit `terraform output -raw admin_password`; state stays local per `.gitignore`. | 2027-02-28 |
| SE-07 | NICs have no NIC-level NSG (`AVD-AZU-0068`) | `modules/domain-controller`, `modules/cluster` | NSGs are associated at the subnet level, the CAF-preferred pattern; duplicating rules per NIC adds drift risk without new protection. | Both subnets carry NSGs with explicit deny-Internet-inbound rules; no VM has a public IP. | 2027-02-28 |
