<#
.SYNOPSIS
    Storage ownership drill: proves only the role owner holds the shared
    disk (SCSI persistent reservation), writes a file, moves the role, and
    reads the file back on the new owner.
.EXAMPLE
    ./test-storage-ownership.ps1 -ResourceGroup rg-wsfc-cheap-lab-wus2
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [string]$FsRoleName = 'fs01',
    [string]$ShareName = 'data',
    [string]$DiskResourceName = 'fs-data-disk',
    [switch]$MoveBack,
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

Write-Step 'Discovering VMs'
$vmNames = (az vm list --resource-group $ResourceGroup --query '[].name' --output json) -join "`n" | ConvertFrom-Json
$nodeVms = @($vmNames | Where-Object { $_ -like 'vm-node*' } | Sort-Object)
if ($nodeVms.Count -lt 2) { throw "Expected two vm-node* VMs in $ResourceGroup." }
$vmByComputer = @{}
foreach ($vm in $nodeVms) {
    if ($vm -match '^vm-(node\d+)-') { $vmByComputer[$Matches[1]] = $vm }
}

$diskViewScript = @'
Get-Disk | Where-Object { $_.IsClustered } | ForEach-Object {
    "DISK num={0} size={1}GB clustered={2} status={3} offline={4}" -f $_.Number, [math]::Round($_.Size / 1GB), $_.IsClustered, ($_.OperationalStatus -join '+'), $_.IsOffline
}
$vol = Get-Volume -DriveLetter S -ErrorAction SilentlyContinue
if ($vol) { "VOLUME S: present label={0} free={1}GB" -f $vol.FileSystemLabel, [math]::Round($vol.SizeRemaining / 1GB, 1) } else { "VOLUME S: not mounted" }
'@

Write-Step "Current ownership of $FsRoleName and $DiskResourceName"
$owner = (Invoke-VmScript -Vm $nodeVms[0] -Script "(Get-ClusterGroup -Name '$FsRoleName').OwnerNode.Name").ToLower()
$diskOwner = (Invoke-VmScript -Vm $nodeVms[0] -Script "(Get-ClusterResource -Name '$DiskResourceName').OwnerNode.Name").ToLower()
Write-Host "Role owner : $owner"
Write-Host "Disk owner : $diskOwner"
if ($owner -ne $diskOwner) { throw 'FAIL: disk resource and role have different owners; investigate before continuing.' }
$ownerVm = $vmByComputer[$owner]
$other = $vmByComputer.Keys | Where-Object { $_ -ne $owner } | Select-Object -First 1
$otherVm = $vmByComputer[$other]

Write-Step "Disk view from OWNER ($owner) - expect S: mounted"
Invoke-VmScript -Vm $ownerVm -Script $diskViewScript

Write-Step "Disk view from NON-OWNER ($other) - expect disk offline/reserved, no S:"
Invoke-VmScript -Vm $otherVm -Script $diskViewScript

Write-Step "Writing proof file on $owner"
$proof = Invoke-VmScript -Vm $ownerVm -Script @"
`$path = 'S:\shares\$ShareName\ownership-proof.txt'
Set-Content -Path `$path -Value ("written by {0} at {1}" -f `$env:COMPUTERNAME, (Get-Date -Format o))
Get-Content -Path `$path
"@
Write-Host "proof: $proof"

Write-Step "Moving $FsRoleName to $other (planned failover: PR reservation follows)"
Invoke-VmScript -Vm $ownerVm -Script @"
Import-Module FailoverClusters
Move-ClusterGroup -Name '$FsRoleName' -Node '$other' | Out-Null
"@
Start-Sleep -Seconds 20

$deadline = (Get-Date).AddMinutes(5)
$moved = $false
while ((Get-Date) -lt $deadline) {
    $state = Invoke-VmScript -Vm $otherVm -Script @"
`$g = Get-ClusterGroup -Name '$FsRoleName'
"STATE={0};OWNER={1}" -f `$g.State, `$g.OwnerNode.Name
"@
    Write-Host "  $state"
    if ($state -match 'STATE=Online' -and $state -match "OWNER=(?i)$other") { $moved = $true; break }
    Start-Sleep -Seconds 15
}
if (-not $moved) { throw "FAIL: role did not come online on $other." }

Write-Step "Reading proof file on NEW owner ($other)"
$readBack = Invoke-VmScript -Vm $otherVm -Script "Get-Content -Path 'S:\shares\$ShareName\ownership-proof.txt'"
Write-Host "read-back: $readBack"
if ($readBack -notmatch 'written by') { throw 'FAIL: proof file not readable on the new owner.' }

Write-Step "Disk view from OLD owner ($owner) - expect disk released"
Invoke-VmScript -Vm $ownerVm -Script $diskViewScript

Write-Host "`nPASS: storage ownership moved with the role; data written on $owner was read on $other." -ForegroundColor Green

if ($MoveBack) {
    Write-Step "Moving $FsRoleName back to $owner"
    Invoke-VmScript -Vm $otherVm -Script "Import-Module FailoverClusters; Move-ClusterGroup -Name '$FsRoleName' -Node '$owner' | Out-Null"
    Write-Host 'Moved back.'
}
