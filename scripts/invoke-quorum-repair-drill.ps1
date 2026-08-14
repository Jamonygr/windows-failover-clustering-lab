<#
.SYNOPSIS
    Quorum-loss and repair drill:
      1. Pin votes (DynamicQuorum off) and block the Cloud Witness.
      2. Deallocate node2 -> the survivor drops below majority and the
         cluster service stops.
      3. Force quorum on node1 (Start-ClusterNode -FixQuorum).
      4. Restore the witness, restart node2, re-enable DynamicQuorum.
.NOTES
    DynamicQuorum is disabled for the drill on purpose: live testing showed
    WSFC's last-man-standing re-weights votes within a couple of minutes of
    the witness failing, letting a single node survive - resilient, but it
    hides the classic majority-loss behavior this drill teaches. Pinning the
    votes makes quorum loss deterministic; the drill restores the default on
    the way out.
    FixQuorum makes the surviving node's cluster database authoritative; in
    production you would use it only after understanding what was lost.
.EXAMPLE
    ./invoke-quorum-repair-drill.ps1 -ResourceGroup rg-wsfc-cheap-lab-wus2 -WitnessAccountName stwsfcwitcheaplabxxxxxx
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [Parameter(Mandatory = $true)][string]$WitnessAccountName,
    [switch]$Force,
    [int]$TimeoutMinutes = 12,
    [string]$SubscriptionId
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }

function Confirm-Phase {
    param([string]$Prompt)
    if ($Force) { return }
    $answer = Read-Host "$Prompt (y/N)"
    if ($answer -notmatch '^[Yy]') { throw 'Drill aborted by user. Re-run when ready; phases are idempotent.' }
}

function Get-RunCommandStdout {
    param([string]$Message)
    if ($Message -match '(?s)\[stdout\]\s*(.*?)\s*\[stderr\]') { return $Matches[1].Trim() }
    return $Message.Trim()
}

function Invoke-VmScript {
    param([string]$Vm, [string]$Script)
    # base64-wrap so multi-line scripts survive the az.cmd argument chain
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Script))
    $wrapper = "iex ([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$encoded')))"
    $raw = (az vm run-command invoke --resource-group $ResourceGroup --name $Vm `
            --command-id RunPowerShellScript --scripts $wrapper --output json) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "run-command failed on $Vm" }
    $parsed = $raw | ConvertFrom-Json
    return Get-RunCommandStdout -Message (($parsed.value | ForEach-Object { $_.message }) -join "`n")
}

function Wait-ForCondition {
    param([string]$Description, [scriptblock]$Condition, [int]$Minutes = 8, [int]$DelaySeconds = 20)
    $deadline = (Get-Date).AddMinutes($Minutes)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $DelaySeconds
        try {
            if (& $Condition) { return }
        }
        catch {
            Write-Host "  waiting ($Description): $($_.Exception.Message)"
        }
    }
    throw "Timed out waiting for: $Description"
}

if ($SubscriptionId) { az account set --subscription $SubscriptionId | Out-Null }

Write-Step 'Discovering VMs'
$vmNames = (az vm list --resource-group $ResourceGroup --query '[].name' --output json) -join "`n" | ConvertFrom-Json
$node1Vm = $vmNames | Where-Object { $_ -like 'vm-node01-*' } | Select-Object -First 1
$node2Vm = $vmNames | Where-Object { $_ -like 'vm-node02-*' } | Select-Object -First 1
if (-not $node1Vm -or -not $node2Vm) { throw "Could not find vm-node01-*/vm-node02-* in $ResourceGroup." }
Write-Host "node1: $node1Vm"
Write-Host "node2: $node2Vm"

Write-Step 'Phase 0: baseline (expect 2 nodes Up, Cloud Witness Online)'
$baseline = Invoke-VmScript -Vm $node1Vm -Script @'
Import-Module FailoverClusters
Get-ClusterNode | ForEach-Object { "NODE {0}={1}" -f $_.Name, $_.State }
Get-ClusterResource | Where-Object ResourceType -eq 'Cloud Witness' | ForEach-Object { "WITNESS={0}" -f $_.State }
'@
Write-Host $baseline
if (($baseline -split "`n" | Where-Object { $_ -match '^NODE .*=Up$' }).Count -lt 2 -or $baseline -notmatch 'WITNESS=Online') {
    throw 'Baseline unhealthy: need both nodes Up and the witness Online before the drill.'
}

Confirm-Phase 'Phase 1: pin votes (DynamicQuorum off) and block the Cloud Witness?'
Write-Step 'Phase 1a: disabling dynamic quorum so votes stay fixed for the drill'
$dq = Invoke-VmScript -Vm $node1Vm -Script @'
Import-Module FailoverClusters
(Get-Cluster).DynamicQuorum = 0
"DynamicQuorum={0}" -f (Get-Cluster).DynamicQuorum
'@
Write-Host "  $dq"

Write-Step 'Phase 1b: blocking Cloud Witness (public network access off)'
az storage account update --resource-group $ResourceGroup --name $WitnessAccountName --public-network-access Disabled --output none
# The cluster health-checks the witness lazily; restarting the resource forces
# an immediate connectivity attempt so the loss is visible right away.
$nudge = Invoke-VmScript -Vm $node1Vm -Script @'
Import-Module FailoverClusters
$w = Get-ClusterResource | Where-Object ResourceType -eq 'Cloud Witness'
try {
    $w | Stop-ClusterResource -ErrorAction Stop | Out-Null
    $w | Start-ClusterResource -ErrorAction Stop | Out-Null
}
catch { }
(Get-ClusterResource | Where-Object ResourceType -eq 'Cloud Witness').State
'@
Write-Host "  witness state after forced re-check: $nudge"
if ($nudge -eq 'Online') {
    Wait-ForCondition -Description 'witness resource leaves Online' -Minutes 5 -Condition {
        $state = Invoke-VmScript -Vm $node1Vm -Script "(Get-ClusterResource | Where-Object ResourceType -eq 'Cloud Witness').State"
        Write-Host "  witness state: $state"
        $state -ne 'Online'
    }
}
Write-Host 'Witness lost. Cluster still has quorum: 2 of 3 (pinned) votes.' -ForegroundColor Yellow

Confirm-Phase 'Phase 2: deallocate node2 and stress quorum?'
Write-Step 'Phase 2: deallocating node2 (1 of 3 pinned votes reachable)'
az vm deallocate --resource-group $ResourceGroup --name $node2Vm --output none

# Two legitimate outcomes: classic quorum loss (ClusSvc stops) or WS2025
# riding through on its quorum resiliency (observed in live testing even
# with DynamicQuorum = 0). Detect which one happened.
$quorumLost = $false
$deadline = (Get-Date).AddMinutes(10)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 20
    try {
        $svc = Invoke-VmScript -Vm $node1Vm -Script "(Get-Service -Name ClusSvc).Status"
        Write-Host "  node1 ClusSvc: $svc"
        if ($svc -match 'Stopped') { $quorumLost = $true; break }
    }
    catch {
        Write-Host "  probe failed: $($_.Exception.Message)"
    }
}

if ($quorumLost) {
    Write-Host 'Quorum lost: the surviving node stopped its cluster service rather than risk split-brain.' -ForegroundColor Yellow

    Confirm-Phase 'Phase 3: force quorum on node1 (-FixQuorum)?'
    Write-Step 'Phase 3: forcing quorum on node1'
    $forceOut = Invoke-VmScript -Vm $node1Vm -Script @'
Import-Module FailoverClusters
Start-ClusterNode -Name $env:COMPUTERNAME -FixQuorum | Out-Null
Start-Sleep -Seconds 20
$node = Get-ClusterNode -Name $env:COMPUTERNAME
"NODE {0}={1}" -f $node.Name, $node.State
"CLUSTER={0}" -f (Get-Cluster).Name
'@
    Write-Host $forceOut
    if ($forceOut -notmatch '=Up') { throw 'FAIL: node1 did not come up in ForceQuorum mode.' }
    Write-Host 'Cluster is running on one node with an authoritative (forced) quorum.' -ForegroundColor Yellow
}
else {
    Write-Step 'Observed: WS2025 quorum resiliency kept the cluster alive'
    $survived = Invoke-VmScript -Vm $node1Vm -Script @'
Import-Module FailoverClusters
"CLUSTER={0} DynamicQuorum={1}" -f (Get-Cluster).Name, (Get-Cluster).DynamicQuorum
Get-ClusterNode | ForEach-Object { "NODE {0}={1}" -f $_.Name, $_.State }
'@
    Write-Host $survived
    Write-Host @'
The surviving node rode through witness + node loss without stopping - even
with DynamicQuorum pinned to 0. Windows Server 2025 hardens two-node quorum
handling beyond the classic majority math; treat this as the drill's second
valid outcome (documented in wiki/architecture/quorum-and-voting.md).
Skipping Phase 3: there is no stopped cluster to force.
'@ -ForegroundColor Yellow
}

Confirm-Phase 'Phase 4: restore the witness and node2?'
Write-Step 'Phase 4a: restoring Cloud Witness access'
az storage account update --resource-group $ResourceGroup --name $WitnessAccountName --public-network-access Enabled --output none
Wait-ForCondition -Description 'witness resource back Online' -Minutes 10 -Condition {
    $state = Invoke-VmScript -Vm $node1Vm -Script @'
$w = Get-ClusterResource | Where-Object ResourceType -eq 'Cloud Witness'
if ($w.State -eq 'Failed' -or $w.State -eq 'Offline') { $w | Start-ClusterResource -ErrorAction SilentlyContinue | Out-Null }
($w | Get-ClusterResource).State
'@
    Write-Host "  witness state: $state"
    $state -eq 'Online'
}

Write-Step 'Phase 4b: starting node2'
az vm start --resource-group $ResourceGroup --name $node2Vm --output none
Wait-ForCondition -Description 'node2 rejoins the cluster' -Minutes $TimeoutMinutes -Condition {
    $nodes = Invoke-VmScript -Vm $node1Vm -Script 'Get-ClusterNode | ForEach-Object { "{0}={1}" -f $_.Name, $_.State }'
    Write-Host "  $($nodes -replace "`n", ' ')"
    (($nodes -split "`n") | Where-Object { $_ -match '=Up$' }).Count -ge 2
}

Write-Step 'Phase 4c: re-enabling dynamic quorum (the production default)'
$dq = Invoke-VmScript -Vm $node1Vm -Script @'
Import-Module FailoverClusters
(Get-Cluster).DynamicQuorum = 1
"DynamicQuorum={0}" -f (Get-Cluster).DynamicQuorum
'@
Write-Host "  $dq"

Write-Step 'Final state'
$final = Invoke-VmScript -Vm $node1Vm -Script @'
Import-Module FailoverClusters
Get-ClusterNode | ForEach-Object { "NODE {0}={1} weight={2}" -f $_.Name, $_.State, $_.NodeWeight }
Get-ClusterResource | Where-Object ResourceType -eq 'Cloud Witness' | ForEach-Object { "WITNESS={0}" -f $_.State }
Get-ClusterGroup | ForEach-Object { "GROUP {0}={1} owner={2}" -f $_.Name, $_.State, $_.OwnerNode }
'@
Write-Host $final
if (($final -split "`n" | Where-Object { $_ -match '^NODE .*=Up' }).Count -ge 2 -and $final -match 'WITNESS=Online') {
    if ($quorumLost) {
        Write-Host "`nPASS: quorum broken, forced, and fully repaired (2 nodes + witness voting again)." -ForegroundColor Green
    }
    else {
        Write-Host "`nPASS: witness and node failure injected and fully repaired; WS2025 quorum resiliency kept the cluster online throughout (no FixQuorum required)." -ForegroundColor Green
    }
}
else {
    throw 'FAIL: final state is not fully healthy; inspect with get-cluster-health.ps1.'
}
