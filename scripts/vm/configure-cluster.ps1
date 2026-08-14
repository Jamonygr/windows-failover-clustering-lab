<#
.SYNOPSIS
    Forms the failover cluster, sets the Cloud Witness, onlines the shared
    disk, and creates the clustered file server role. Runs on node1 only.
.NOTES
    Run commands execute as SYSTEM, which cannot create the cluster's AD
    computer objects. This wrapper therefore relays the work to a scheduled
    task running as the domain admin (password logon = full network token, no
    double-hop). Secrets transit through protected run-command parameters and
    an ACL-restricted config file that is deleted in finally (SE-05).
#>
param(
    [Parameter(Mandatory = $true)][string]$ClusterName,
    [Parameter(Mandatory = $true)][string]$NodeNames,
    [Parameter(Mandatory = $true)][string]$FsRoleName,
    [Parameter(Mandatory = $true)][string]$FsRoleIp,
    [Parameter(Mandatory = $true)][string]$ShareName,
    [Parameter(Mandatory = $true)][string]$SharedDiskSizeGb,
    [Parameter(Mandatory = $true)][string]$DomainNetbiosName,
    [Parameter(Mandatory = $true)][string]$AdminUsername,
    [Parameter(Mandatory = $true)][string]$WitnessAccountName,
    [Parameter(Mandatory = $true)][string]$AdminPassword,
    [Parameter(Mandatory = $true)][string]$WitnessAccountKey
)

$ErrorActionPreference = 'Stop'
$baseDir = 'C:\ProgramData\wsfclab'
$logDir = Join-Path $baseDir 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Start-Transcript -Path (Join-Path $logDir 'configure-cluster-outer.log') -Append | Out-Null

$configPath = Join-Path $baseDir 'configure-config.json'
$innerPath = Join-Path $baseDir 'configure-cluster-inner.ps1'
$resultPath = Join-Path $baseDir 'configure-result.json'
$innerLog = Join-Path $logDir 'configure-cluster-inner.log'
$taskName = 'wsfclab-configure-cluster'

function Test-AlreadyConfigured {
    param([string]$RoleName)
    try {
        Import-Module FailoverClusters -ErrorAction Stop
        if (-not (Get-Cluster -ErrorAction SilentlyContinue)) { return $false }
        $witness = Get-ClusterResource | Where-Object { $_.ResourceType -eq 'Cloud Witness' }
        $role = Get-ClusterGroup -Name $RoleName -ErrorAction SilentlyContinue
        return [bool]($witness -and $role)
    }
    catch {
        return $false
    }
}

# Worker script; single-quoted here-string, so nothing interpolates here.
$innerScript = @'
param([Parameter(Mandatory = $true)][string]$ConfigPath)

$ErrorActionPreference = 'Stop'
$baseDir = 'C:\ProgramData\wsfclab'
$resultPath = Join-Path $baseDir 'configure-result.json'
Start-Transcript -Path (Join-Path $baseDir 'logs\configure-cluster-inner.log') -Append | Out-Null

$success = $false
$message = ''
try {
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    Import-Module FailoverClusters

    # 1. Wait for the partner node to answer on SMB
    $partners = @($config.Nodes | Where-Object { $_ -ne $env:COMPUTERNAME })
    foreach ($partner in $partners) {
        $deadline = (Get-Date).AddMinutes(20)
        while (-not (Test-NetConnection -ComputerName $partner -Port 445 -InformationLevel Quiet -WarningAction SilentlyContinue)) {
            if ((Get-Date) -gt $deadline) { throw "Timed out waiting for $partner on port 445." }
            Start-Sleep -Seconds 15
        }
        Write-Output "$partner reachable on 445."
    }

    # 2. Create the cluster with a Distributed Network Name management point
    #    (resolves to the node IPs, so no load balancer is needed for the CNO)
    if (-not (Get-Cluster -ErrorAction SilentlyContinue)) {
        Write-Output "Creating cluster $($config.ClusterName) with nodes: $($config.Nodes -join ', ')."
        New-Cluster -Name $config.ClusterName -Node $config.Nodes -ManagementPointNetworkType Distributed -NoStorage | Out-Null
    }
    else {
        Write-Output 'Cluster already exists.'
    }

    $deadline = (Get-Date).AddMinutes(10)
    while (@(Get-ClusterNode | Where-Object { $_.State -ne 'Up' }).Count -gt 0) {
        if ((Get-Date) -gt $deadline) { throw 'Timed out waiting for all cluster nodes to reach Up.' }
        Start-Sleep -Seconds 10
    }
    Write-Output 'All nodes Up.'

    # 3. Cloud Witness quorum (blob endpoint reached via the storage service
    #    endpoint; DNS resolves through the DC forwarder 168.63.129.16)
    if (-not (Get-ClusterResource | Where-Object { $_.ResourceType -eq 'Cloud Witness' })) {
        $attempt = 0
        while ($true) {
            try {
                $attempt++
                Set-ClusterQuorum -CloudWitness -AccountName $config.WitnessAccountName -AccessKey $config.WitnessAccountKey | Out-Null
                break
            }
            catch {
                if ($attempt -ge 3) { throw "Cloud Witness configuration failed after $attempt attempts: $($_.Exception.Message)" }
                Write-Output "Cloud Witness attempt $attempt failed; retrying in 30s."
                Start-Sleep -Seconds 30
            }
        }
        Write-Output 'Cloud Witness configured.'
    }
    else {
        Write-Output 'Cloud Witness already configured.'
    }

    # 4. Initialize and add the shared disk (GPT + NTFS on a Basic disk, the
    #    layout WSFC requires; host caching is already None at the platform)
    if (-not (Get-ClusterResource | Where-Object { $_.ResourceType -eq 'Physical Disk' })) {
        $expectedBytes = [int64]$config.SharedDiskSizeGb * 1GB
        $rawDisk = Get-Disk |
            Where-Object { $_.PartitionStyle -eq 'RAW' -and [math]::Abs($_.Size - $expectedBytes) -lt 2GB } |
            Select-Object -First 1
        if (-not $rawDisk) {
            $rawDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' } | Select-Object -First 1
        }

        if ($rawDisk) {
            Write-Output "Initializing disk $($rawDisk.Number) ($([math]::Round($rawDisk.Size / 1GB)) GiB)."
            if ($rawDisk.IsOffline) { Set-Disk -Number $rawDisk.Number -IsOffline $false }
            if ($rawDisk.IsReadOnly) { Set-Disk -Number $rawDisk.Number -IsReadOnly $false }
            Initialize-Disk -Number $rawDisk.Number -PartitionStyle GPT -PassThru | Out-Null
            New-Partition -DiskNumber $rawDisk.Number -UseMaximumSize -DriveLetter S | Out-Null
            Format-Volume -DriveLetter S -FileSystem NTFS -NewFileSystemLabel 'ClusterData' -Confirm:$false | Out-Null
        }
        elseif (-not (Get-Volume -DriveLetter S -ErrorAction SilentlyContinue)) {
            throw 'No RAW disk found and no S: volume present; shared disk attachment looks wrong.'
        }

        $available = Get-ClusterAvailableDisk
        if (-not $available) { throw 'Shared disk is not visible as a cluster-available disk on both nodes.' }
        $available | Add-ClusterDisk | Out-Null
        Write-Output 'Shared disk added to the cluster.'
    }

    $diskResource = Get-ClusterResource | Where-Object { $_.ResourceType -eq 'Physical Disk' } | Select-Object -First 1
    if ($diskResource.Name -ne 'fs-data-disk') {
        $diskResource.Name = 'fs-data-disk'
        Write-Output 'Cluster disk renamed to fs-data-disk.'
    }

    # 5. File server role with a static IP (reachable from clients only
    #    through the optional internal load balancer)
    if (-not (Get-ClusterGroup -Name $config.FsRoleName -ErrorAction SilentlyContinue)) {
        Write-Output "Creating file server role $($config.FsRoleName) at $($config.FsRoleIp)."
        Add-ClusterFileServerRole -Name $config.FsRoleName -Storage 'fs-data-disk' -StaticAddress $config.FsRoleIp | Out-Null
    }

    $deadline = (Get-Date).AddMinutes(10)
    while ((Get-ClusterGroup -Name $config.FsRoleName).State -ne 'Online') {
        if ((Get-Date) -gt $deadline) { throw "Timed out waiting for role $($config.FsRoleName) to come online." }
        Start-Sleep -Seconds 10
    }

    # 6. Clustered SMB share (created on the current role owner)
    $group = Get-ClusterGroup -Name $config.FsRoleName
    if ($group.OwnerNode.Name -ne $env:COMPUTERNAME) {
        Move-ClusterGroup -Name $config.FsRoleName -Node $env:COMPUTERNAME | Out-Null
        Start-Sleep -Seconds 15
    }
    $sharePath = Join-Path 'S:\shares' $config.ShareName
    New-Item -ItemType Directory -Force -Path $sharePath | Out-Null
    if (-not (Get-SmbShare -Name $config.ShareName -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $config.ShareName -Path $sharePath -ScopeName $config.FsRoleName `
            -FullAccess "$($config.DomainNetbiosName)\Domain Admins" `
            -ChangeAccess "$($config.DomainNetbiosName)\Domain Users" | Out-Null
        Write-Output "Share \\$($config.FsRoleName)\$($config.ShareName) created."
    }

    $success = $true
    $message = 'Cluster, witness, shared disk, and file server role configured.'
}
catch {
    $message = $_.Exception.Message
    Write-Output "FAILED: $message"
}
finally {
    @{
        Success      = $success
        Message      = $message
        CompletedUtc = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json | Set-Content -Path $resultPath -Encoding UTF8
    Remove-Item -Path $ConfigPath -Force -ErrorAction SilentlyContinue
    Stop-Transcript | Out-Null
}
'@

try {
    if (Test-AlreadyConfigured -RoleName $FsRoleName) {
        Write-Output 'Cluster, witness, and role already configured; nothing to do.'
        exit 0
    }

    Remove-Item -Path $resultPath -Force -ErrorAction SilentlyContinue
    Set-Content -Path $innerPath -Value $innerScript -Encoding UTF8

    $config = @{
        ClusterName        = $ClusterName
        Nodes              = @($NodeNames -split ',' | ForEach-Object { $_.Trim() })
        FsRoleName         = $FsRoleName
        FsRoleIp           = $FsRoleIp
        ShareName          = $ShareName
        SharedDiskSizeGb   = [int]$SharedDiskSizeGb
        DomainNetbiosName  = $DomainNetbiosName
        WitnessAccountName = $WitnessAccountName
        WitnessAccountKey  = $WitnessAccountKey
    }
    $config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
    & icacls.exe $configPath /inheritance:r /grant 'SYSTEM:F' /grant 'Administrators:F' | Out-Null

    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$innerPath`" -ConfigPath `"$configPath`""
    Register-ScheduledTask -TaskName $taskName -Action $action `
        -User "$DomainNetbiosName\$AdminUsername" -Password $AdminPassword -RunLevel Highest | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Write-Output "Scheduled task $taskName started as $DomainNetbiosName\$AdminUsername."

    $deadline = (Get-Date).AddMinutes(35)
    $result = $null
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 20
        if (Test-Path $resultPath) {
            $result = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
            break
        }
        $state = (Get-ScheduledTask -TaskName $taskName).State
        if ($state -eq 'Ready') {
            Start-Sleep -Seconds 10
            if (Test-Path $resultPath) {
                $result = Get-Content -Path $resultPath -Raw | ConvertFrom-Json
            }
            else {
                throw 'Configuration task finished without writing a result; check logs\configure-cluster-inner.log.'
            }
            break
        }
    }

    if (Test-Path $innerLog) {
        Write-Output '--- inner log (tail) ---'
        Get-Content -Path $innerLog -Tail 60 | ForEach-Object { Write-Output $_ }
        Write-Output '--- end inner log ---'
    }

    if (-not $result) { throw 'Timed out waiting for the cluster configuration task.' }
    if (-not $result.Success) { throw "Cluster configuration failed: $($result.Message)" }

    Write-Output $result.Message
    Get-ClusterNode | ForEach-Object { Write-Output ("node: {0} = {1}" -f $_.Name, $_.State) }
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path $configPath, $innerPath -Force -ErrorAction SilentlyContinue
    Stop-Transcript | Out-Null
}
