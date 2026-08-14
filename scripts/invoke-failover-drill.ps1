<#
.SYNOPSIS
    Failover drill: deallocates the node that owns the file server role,
    proves the role fails over to the surviving node, optionally restores.
.EXAMPLE
    ./invoke-failover-drill.ps1 -ResourceGroup rg-wsfc-cheap-lab-wus2 -Restore
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [string]$FsRoleName = 'fs01',
    [switch]$Restore,
    [switch]$Force,
    [int]$TimeoutMinutes = 10,
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
    $raw = (az vm run-command invoke --resource-group $ResourceGroup --name $Vm `
            --command-id RunPowerShellScript --scripts $Script --output json) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "run-command failed on $Vm" }
    $parsed = $raw | ConvertFrom-Json
    return Get-RunCommandStdout -Message (($parsed.value | ForEach-Object { $_.message }) -join "`n")
}

if ($SubscriptionId) { az account set --subscription $SubscriptionId | Out-Null }

Write-Step 'Discovering cluster node VMs'
$vmNames = (az vm list --resource-group $ResourceGroup --query '[].name' --output json) -join "`n" | ConvertFrom-Json
$nodeVms = @($vmNames | Where-Object { $_ -like 'vm-node*' } | Sort-Object)
if ($nodeVms.Count -lt 2) { throw "Expected two vm-node* VMs in $ResourceGroup." }

# Azure VM name -> Windows computer name (vm-node01-... -> node01)
$vmByComputer = @{}
foreach ($vm in $nodeVms) {
    if ($vm -match '^vm-(node\d+)-') { $vmByComputer[$Matches[1]] = $vm }
}

Write-Step "Current owner of role $FsRoleName"
$owner = Invoke-VmScript -Vm $nodeVms[0] -Script "(Get-ClusterGroup -Name '$FsRoleName').OwnerNode.Name"
$owner = $owner.ToLower()
if (-not $vmByComputer.ContainsKey($owner)) { throw "Owner '$owner' does not map to a lab VM." }
$ownerVm = $vmByComputer[$owner]
$survivor = ($vmByComputer.Keys | Where-Object { $_ -ne $owner } | Select-Object -First 1)
$survivorVm = $vmByComputer[$survivor]
Write-Host "Owner: $owner ($ownerVm)"
Write-Host "Survivor: $survivor ($survivorVm)"

if (-not $Force) {
    $answer = Read-Host "Deallocate $ownerVm to force a failover? (y/N)"
    if ($answer -notmatch '^[Yy]') { Write-Host 'Aborted.'; exit 0 }
}

Write-Step "Deallocating $ownerVm (hard node failure)"
az vm deallocate --resource-group $ResourceGroup --name $ownerVm --output none
if ($LASTEXITCODE -ne 0) { throw "Failed to deallocate $ownerVm." }
Write-Host 'Deallocated.'

Write-Step "Waiting for $FsRoleName to come online on $survivor"
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$passed = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 20
    try {
        $state = Invoke-VmScript -Vm $survivorVm -Script @"
`$g = Get-ClusterGroup -Name '$FsRoleName'
"STATE={0};OWNER={1}" -f `$g.State, `$g.OwnerNode.Name
"@
        Write-Host "  $state"
        if ($state -match 'STATE=Online' -and $state -match "OWNER=(?i)$survivor") { $passed = $true; break }
    }
    catch {
        Write-Host "  survivor not answering yet: $($_.Exception.Message)"
    }
}

if (-not $passed) { throw "FAIL: role $FsRoleName did not come online on $survivor within $TimeoutMinutes minutes." }
Write-Host "`nPASS: $FsRoleName failed over from $owner to $survivor." -ForegroundColor Green

if ($Restore) {
    Write-Step "Restoring $ownerVm"
    az vm start --resource-group $ResourceGroup --name $ownerVm --output none
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 20
        $nodes = Invoke-VmScript -Vm $survivorVm -Script 'Get-ClusterNode | ForEach-Object { "{0}={1}" -f $_.Name, $_.State }'
        Write-Host "  $($nodes -replace "`n", ' ')"
        if (($nodes -split "`n" | Where-Object { $_ -match '=Up$' }).Count -ge 2) {
            Write-Host "`nCluster restored: both nodes Up. Role stays on $survivor until moved." -ForegroundColor Green
            exit 0
        }
    }
    throw "FAIL: $owner did not rejoin the cluster within $TimeoutMinutes minutes."
}
else {
    Write-Host "Restore later with: az vm start -g $ResourceGroup -n $ownerVm"
}
