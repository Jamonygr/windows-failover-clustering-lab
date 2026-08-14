<#
.SYNOPSIS
    Prints cluster, quorum, node, group, and resource state from a live node.
.EXAMPLE
    ./get-cluster-health.ps1 -ResourceGroup rg-wsfc-cheap-lab-wus2
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [string]$VmName,
    [string]$SubscriptionId
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }

function Get-RunCommandStdout {
    param([string]$Message)
    if ($Message -match '(?s)\[stdout\]\s*(.*?)\s*\[stderr\]') { return $Matches[1].Trim() }
    return $Message.Trim()
}

function Invoke-VmScript {
    param([string]$Vm, [string]$Script)
    # az returns a string array; join before parsing (and before any -match)
    $raw = (az vm run-command invoke --resource-group $ResourceGroup --name $Vm `
            --command-id RunPowerShellScript --scripts $Script --output json) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "run-command failed on $Vm" }
    $parsed = $raw | ConvertFrom-Json
    return Get-RunCommandStdout -Message (($parsed.value | ForEach-Object { $_.message }) -join "`n")
}

function Get-VmPowerState {
    param([string]$Vm)
    return (az vm get-instance-view --resource-group $ResourceGroup --name $Vm `
            --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus | [0]" --output tsv)
}

if ($SubscriptionId) { az account set --subscription $SubscriptionId | Out-Null }

Write-Step 'Locating cluster nodes'
$vmNames = (az vm list --resource-group $ResourceGroup --query '[].name' --output json) -join "`n" | ConvertFrom-Json
$nodeVms = @($vmNames | Where-Object { $_ -like 'vm-node*' } | Sort-Object)
if (-not $nodeVms) { throw "No vm-node* VMs found in $ResourceGroup." }

$target = $VmName
if (-not $target) {
    foreach ($candidate in $nodeVms) {
        if ((Get-VmPowerState -Vm $candidate) -eq 'VM running') { $target = $candidate; break }
    }
}
if (-not $target) { throw 'No running cluster node found; start one with az vm start.' }
Write-Host "Querying via $target"

$healthScript = @'
Import-Module FailoverClusters -ErrorAction Stop
$cluster = Get-Cluster
"CLUSTER : {0}" -f $cluster.Name
"QUORUM  : {0}" -f ((Get-ClusterQuorum).QuorumResource | ForEach-Object { $_.Name })
"NODES"
Get-ClusterNode | ForEach-Object { "  {0,-12} state={1,-8} weight={2}" -f $_.Name, $_.State, $_.NodeWeight }
"GROUPS"
Get-ClusterGroup | ForEach-Object { "  {0,-20} state={1,-10} owner={2}" -f $_.Name, $_.State, $_.OwnerNode }
"RESOURCES"
Get-ClusterResource | ForEach-Object { "  {0,-24} state={1,-10} type={2,-16} owner={3}" -f $_.Name, $_.State, $_.ResourceType, $_.OwnerNode }
'@

Write-Step 'Cluster health'
Invoke-VmScript -Vm $target -Script $healthScript

Write-Step 'VM power states'
foreach ($vm in $vmNames | Sort-Object) {
    '{0,-40} {1}' -f $vm, (Get-VmPowerState -Vm $vm)
}
