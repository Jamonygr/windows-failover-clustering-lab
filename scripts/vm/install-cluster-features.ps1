<#
.SYNOPSIS
    Installs the Failover Clustering and File Server features on a node.
.NOTES
    Runs as SYSTEM via Azure run command after the domain join. Reboots
    unconditionally (scheduled, after exit) so the follow-on cluster
    configuration always starts from a settled node.
#>
$ErrorActionPreference = 'Stop'
$baseDir = 'C:\ProgramData\wsfclab'
$logDir = Join-Path $baseDir 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Start-Transcript -Path (Join-Path $logDir 'install-cluster-features.log') -Append | Out-Null

try {
    $marker = Join-Path $baseDir 'features-installed.marker'
    if (Test-Path $marker) {
        Write-Output 'Cluster features already installed; nothing to do.'
        exit 0
    }

    Write-Output 'Installing Failover-Clustering, FS-FileServer, RSAT-Clustering-PowerShell.'
    $result = Install-WindowsFeature -Name Failover-Clustering, FS-FileServer, RSAT-Clustering-PowerShell -IncludeManagementTools
    if (-not $result.Success) {
        throw "Install-WindowsFeature reported failure (exit code: $($result.ExitCode))."
    }

    New-Item -ItemType File -Force -Path $marker | Out-Null
    Write-Output "Features installed (RestartNeeded: $($result.RestartNeeded)); rebooting in 30 seconds."
    & shutdown.exe /r /t 30 /c 'WSFC feature installation'
    exit 0
}
catch {
    Write-Error "Feature installation failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Stop-Transcript | Out-Null
}
