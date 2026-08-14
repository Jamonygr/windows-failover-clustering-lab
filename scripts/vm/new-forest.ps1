<#
.SYNOPSIS
    Promotes a fresh WS2025 VM to the first domain controller of a new forest.
.NOTES
    Runs as SYSTEM via Azure run command. A reboot inside a run command fails
    the execution, so the script schedules shutdown /r /t 30 and exits 0; the
    domain-controller module's time_sleep covers the reboot and AD warm-up.
    168.63.129.16 is the Azure recursive resolver, reachable without any
    outbound internet access.
#>
param(
    [Parameter(Mandatory = $true)][string]$DomainName,
    [Parameter(Mandatory = $true)][string]$DomainNetbiosName,
    [Parameter(Mandatory = $true)][string]$SafeModePassword
)

$ErrorActionPreference = 'Stop'
$logDir = 'C:\ProgramData\wsfclab\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Start-Transcript -Path (Join-Path $logDir 'new-forest.log') -Append | Out-Null

function Set-AzureDnsForwarder {
    try {
        $existing = @((Get-DnsServerForwarder -ErrorAction Stop).IPAddress | ForEach-Object { $_.IPAddressToString })
        if ($existing -notcontains '168.63.129.16') {
            Add-DnsServerForwarder -IPAddress 168.63.129.16 -ErrorAction Stop
            Write-Output 'DNS forwarder 168.63.129.16 added.'
        }
        else {
            Write-Output 'DNS forwarder 168.63.129.16 already present.'
        }
    }
    catch {
        Write-Output "DNS forwarder not set: $($_.Exception.Message)"
    }
}

try {
    $domainRole = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole
    if ($domainRole -ge 4) {
        Write-Output 'Already a domain controller; nothing to do.'
        Set-AzureDnsForwarder
        exit 0
    }

    Write-Output 'Installing AD DS and DNS roles.'
    Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools | Out-Null

    Write-Output "Promoting forest $DomainName ($DomainNetbiosName)."
    Import-Module ADDSDeployment
    $securePassword = ConvertTo-SecureString -String $SafeModePassword -AsPlainText -Force
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $DomainNetbiosName `
        -SafeModeAdministratorPassword $securePassword `
        -InstallDns `
        -NoRebootOnCompletion `
        -Force `
        -WarningAction SilentlyContinue | Out-Null

    Set-AzureDnsForwarder

    Write-Output 'Forest promotion complete; rebooting in 30 seconds.'
    & shutdown.exe /r /t 30 /c 'AD DS forest promotion'
    exit 0
}
catch {
    Write-Error "Forest promotion failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Stop-Transcript | Out-Null
}
