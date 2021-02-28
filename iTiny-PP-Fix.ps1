Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools
# переменные 
Write-Host "Важно! проверить структуру подпапок в папке SITE" -ForegroundColor Yellow
Write-Host "Важно! проверить структуру подпапок в папке SERVICE" -ForegroundColor Yellow
Write-Host "Важно! проверить необходимость остановки пуллов/служб" -ForegroundColor Yellow

Pause

if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$iTinySite = "iTinyPP"
$iTinyService = "LS.iTiny.Sync"
$UpdateFolder = ""
$UpdateFolderLocal = ""
$UpdateFolderNet = $Global:UpdateFolderNet  #"\\vm-fs2\LSUpdates"
$UpdateNet = $Global:UpdateFolderNet
$stopIIS = $false
$stopService = $true
#
# ---- определение корневой папки апдейта
if (!(Test-Path U:\)) {
    # монтируем папку с апдейтами на букву диска для сокращения путей (есть очень длинные)
    $UpdateDisk = New-Object -ComObject WScript.Network
    $UpdateDisk.MapNetworkDrive( "U:", $UpdateFolderNet, "false")
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $UpdateNet }
$TempStr = Get-ChildItem -Path $UpdateFolder -Filter $Global:UpdateByDayTemplate | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$UpdateNet = Join-Path $UpdateNet -ChildPath $TempStr
#$UpdateFolder = "\\vm-fs2\LSUpdates\"
#
$iTinyBuild = Join-Path -Path $UpdateFolder -ChildPath "iTiny"
$iTinyBuildNet = Join-Path -Path $UpdateNet -ChildPath "iTiny"
Write-Host "используем для обновления $iTinyBuildNet" -ForegroundColor Magenta
pause

# проверяем нужно ли пересоздавать объекты с массивами.
if (!($HostsRS)) { $HostsRS=@() }
if (!($HostsRSlist)) { $HostsRSlist=@()  } # оптимизированный перечень хостов, без повторов.


# открываем удаленные сеансы к серверным хостам с комплексом iTiny
foreach ($Apphost in $Global:iTinyHosts) {
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}

# обновляем библиотеку в каталоге АПП сервера с предварительной остановкой пулла IIS
if ( Test-Path "$iTinyBuild\site") {
    Write-Host "Установка фиксов для сайта/web-приложения"
    foreach ($apphost in $HostsRS) {
        Write-Host "начинаем обновление на хосте $($Apphost.ComputerName)" -ForegroundColor Yellow
        pause
        if ($stopIIS) {
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -SiteName $args[2] -BackupMode -StopPoolBefore -NetAccount $args[3]
            } -ArgumentList "$iTinyBuildNet\site", $iTinyBuildNet, $iTinySite, $cred
        } else {
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -SiteName $args[2] -BackupMode -NetAccount $args[3]
            } -ArgumentList "$iTinyBuildNet\site", $iTinyBuildNet, $iTinySite, $cred
        }
    }
    Write-Host "Обновленные файлы скопированы на сайты" -ForegroundColor Green
}

# проводим обновления файлов службы/сервиса 
if ( Test-Path "$iTinyBuild\service") {
    Write-Host "Установка фиксов для службы/сервиса"
    foreach ($apphost in $HostsRS) {
        Write-Host "начинаем обновление на хосте $($Apphost.ComputerName)" -ForegroundColor Yellow
        pause
        if ($stopService) {
             Invoke-Command -Session $apphost { 
                Update-DevOpsToolsServiceFix -BuildDir $args[0] -BackupDir  $args[1] -ServiceName $args[3] -BackupMode -StopServiceBefore -NetAccount $args[2] 
            } -ArgumentList "$iTinyBuildNet\service", $iTinyBuildNet, $cred, $iTinyService
       } else {
             Invoke-Command -Session $apphost { 
                Update-DevOpsToolsServiceFix -BuildDir $args[0] -BackupDir  $args[1] -ServiceName $args[3] -BackupMode -NetAccount $args[2] 
            } -ArgumentList "$iTinyBuildNet\service", $iTinyBuildNet, $cred, $iTinyService
        }
    }
    Write-Host "Обновленные файлы скопированы для служб" -ForegroundColor Green
}
Write-Host "выполенние окончено" -ForegroundColor Green