<#
.SYNOPSIS
    Points the clustered file server IP resource at the internal load
    balancer health probe so Azure can route traffic to the role owner.
.NOTES
    Runs as SYSTEM via Azure run command; local cluster management does not
    need a domain identity. The role restarts to apply the probe settings.
#>
param(
    [Parameter(Mandatory = $true)][string]$FsRoleName,
    [Parameter(Mandatory = $true)][string]$FsRoleIp,
    [Parameter(Mandatory = $true)][string]$ProbePort
)

$ErrorActionPreference = 'Stop'
$logDir = 'C:\ProgramData\wsfclab\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Start-Transcript -Path (Join-Path $logDir 'set-ilb-probe.log') -Append | Out-Null

try {
    Import-Module FailoverClusters

    $ipResource = Get-ClusterResource | Where-Object {
        $_.ResourceType -eq 'IP Address' -and $_.OwnerGroup.Name -eq $FsRoleName
    } | Select-Object -First 1
    if (-not $ipResource) { throw "No IP Address resource found in group $FsRoleName." }

    $currentProbe = ($ipResource | Get-ClusterParameter -Name ProbePort).Value
    if ($currentProbe -eq [int]$ProbePort) {
        Write-Output "Probe port already set to $ProbePort; nothing to do."
        exit 0
    }

    $clusterNetwork = (Get-ClusterNetwork | Select-Object -First 1).Name
    $ipResource | Set-ClusterParameter -Multiple @{
        Address              = $FsRoleIp
        ProbePort            = [int]$ProbePort
        SubnetMask           = '255.255.255.255'
        Network              = $clusterNetwork
        EnableDhcp           = 0
        OverrideAddressMatch = 1
    }

    Write-Output "Restarting $FsRoleName to apply probe settings."
    Stop-ClusterGroup -Name $FsRoleName | Out-Null
    Start-ClusterGroup -Name $FsRoleName | Out-Null

    $deadline = (Get-Date).AddMinutes(5)
    while ((Get-ClusterGroup -Name $FsRoleName).State -ne 'Online') {
        if ((Get-Date) -gt $deadline) { throw "Role $FsRoleName did not come back online." }
        Start-Sleep -Seconds 10
    }

    Write-Output "Probe port $ProbePort configured on $($ipResource.Name); role online."
    exit 0
}
catch {
    Write-Error "Probe configuration failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Stop-Transcript | Out-Null
}
