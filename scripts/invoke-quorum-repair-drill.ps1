<#
.SYNOPSIS
    Quorum-loss and repair drill:
      1. Block the Cloud Witness (storage firewall) while both nodes are up.
      2. Deallocate node2 -> the survivor drops below majority and the
         cluster service stops.
      3. Force quorum on node1 (Start-ClusterNode -FixQuorum).
      4. Restore the witness and restart node2; verify all votes return.
.NOTES
    The witness is blocked BEFORE the node failure on purpose: dynamic quorum
    would otherwise remove the down node's vote and dynamic witness would
    re-weight, keeping the cluster alive and spoiling the drill.
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
    $raw = (az vm run-command invoke --resource-group $ResourceGroup --name $Vm `
            --command-id RunPowerShellScript --scripts $Script --output json) -join "`n"
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

Confirm-Phase 'Phase 1: block the Cloud Witness via the storage firewall?'
Write-Step 'Phase 1: blocking Cloud Witness (public network access off)'
az storage account update --resource-group $ResourceGroup --name $WitnessAccountName --public-network-access Disabled --output none
Wait-ForCondition -Description 'witness resource leaves Online' -Minutes 8 -Condition {
    $state = Invoke-VmScript -Vm $node1Vm -Script "(Get-ClusterResource | Where-Object ResourceType -eq 'Cloud Witness').State"
    Write-Host "  witness state: $state"
    $state -ne 'Online'
}
Write-Host 'Witness lost. Cluster still has quorum: 2 of 3 votes.' -ForegroundColor Yellow

Confirm-Phase 'Phase 2: deallocate node2 and lose quorum?'
Write-Step 'Phase 2: deallocating node2 (now 1 of 3 votes -> quorum loss)'
az vm deallocate --resource-group $ResourceGroup --name $node2Vm --output none
Wait-ForCondition -Description 'cluster service stops on node1 (quorum lost)' -Minutes 10 -Condition {
    $svc = Invoke-VmScript -Vm $node1Vm -Script "(Get-Service -Name ClusSvc).Status"
    Write-Host "  node1 ClusSvc: $svc"
    $svc -match 'Stopped'
}
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

Write-Step 'Final state'
$final = Invoke-VmScript -Vm $node1Vm -Script @'
Import-Module FailoverClusters
Get-ClusterNode | ForEach-Object { "NODE {0}={1} weight={2}" -f $_.Name, $_.State, $_.NodeWeight }
Get-ClusterResource | Where-Object ResourceType -eq 'Cloud Witness' | ForEach-Object { "WITNESS={0}" -f $_.State }
Get-ClusterGroup | ForEach-Object { "GROUP {0}={1} owner={2}" -f $_.Name, $_.State, $_.OwnerNode }
'@
Write-Host $final
if (($final -split "`n" | Where-Object { $_ -match '^NODE .*=Up' }).Count -ge 2 -and $final -match 'WITNESS=Online') {
    Write-Host "`nPASS: quorum broken, forced, and fully repaired (2 nodes + witness voting again)." -ForegroundColor Green
}
else {
    throw 'FAIL: final state is not fully healthy; inspect with get-cluster-health.ps1.'
}
