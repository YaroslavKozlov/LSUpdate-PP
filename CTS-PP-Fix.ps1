Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools
# переменные 
Write-Host "Важно! проверить структуру подпапок в папке SERVER" -ForegroundColor Yellow
Write-Host "Важно! проверить структуру подпапок в папке AUTH" -ForegroundColor Yellow
Write-Host "Важно! проверить структуру подпапок в папке SYNC" -ForegroundColor Yellow
Write-Host "Важно! проверить необходимость остановки пуллов/служб" -ForegroundColor Yellow

Pause

if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName "scrooge\ab"}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$CTSSite = "Default Web Site"
$CTSinstance = "CTSWebApp"
$CTSAuthService = "Lime.Cts.Authorization"
#
$CTSSyncServices = @("Lime.Cts.Synchronization","Lime.CTS.Syncronization_SC","Lime.CtsDEV.Synchronization")
$CTSSyncTaskPath = @{
    'Lime.Cts.Synchronization' = '\Lime Systems\CTS-SYNC\'
    'Lime.CTS.Syncronization_SC' = '\Lime Systems\SC-SYNC\'
} #>
<# DEV 
$CTSSyncServices = @("Lime.CtsDEV.Synchronization")
$CTSSyncTaskPath = @{
    'Lime.CtsDEV.Synchronization' = '\Lime Systems\CTS-SYNC-DEV\'
}
#>
$UpdateFolder = ""
$UpdateFolderLocal = ""
$scriptUpdateFolderNet = $Global:UpdateFolderNet  #"\\vm-fs2\LSUpdates"
$UpdateNet = $Global:UpdateFolderNet
$scriptCTSHosts = $('vm-app-cts2') #$Global:CTSHosts

$stopIIS = $true
$stopServiceAuth = $true
$stopServiceSync = $true
#
# ---- определение корневой папки апдейта
if (!(Test-Path U:\)) {
    # монтируем папку с апдейтами на букву диска для сокращения путей (есть очень длинные)
    $UpdateDisk = New-Object -ComObject WScript.Network
    $UpdateDisk.MapNetworkDrive( "U:", $scriptUpdateFolderNet, "false")
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $UpdateNet }
$TempStr = Get-ChildItem -Path $UpdateFolder -Filter $Global:UpdateByDayTemplate | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$UpdateNet = Join-Path $UpdateNet -ChildPath $TempStr
#$UpdateFolder = "\\vm-fs2\LSUpdates\"
#
$CTSBuild = Join-Path -Path $UpdateFolder -ChildPath "CTS"
$CTSBuildNet = Join-Path -Path $UpdateNet -ChildPath "CTS"
if (Test-Path $CTSBuildNet ) {
    Write-Host "используем для обновления $CTSBuildNet" -ForegroundColor Magenta
} else {
    Write-Host "папка $CTSBuildNet отсутствует" -ForegroundColor Red
}
pause
Write-Host "Контрольное удаление .config в UPDATE-папке  CTS\Server" 
$appfiles = Get-ChildItem -Path "$CTSBuildNet\server\*.config" -Attributes !Directory+!System 
$configlist = @("NLog.config","Web.config")
if ($appfiles) {
    # если в выборке есть файлы *.config
    foreach ($appfile in $appfiles) {
        if ($configlist -contains $appfile.Name ) {
            Remove-Item -Path $appfile.FullName -Force; 
            Write-Host " удален $($appfile.FullName)" -ForegroundColor Green 
        }
    }
} else {Write-Host " не найдены" -ForegroundColor Red}

# проверяем нужно ли пересоздавать объекты с массивами.
if (!($HostsRS)) { $HostsRS=@() }
if (!($HostsRSlist)) { $HostsRSlist=@()  } # оптимизированный перечень хостов, без повторов.


# открываем удаленные сеансы к серверным хостам с комплексом CTS
foreach ($Apphost in $scriptCTSHosts) {
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}

# обновляем библиотеку в каталоге АПП сервера с предварительной остановкой пулла IIS
if ( Test-Path "$CTSBuild\server") {
    Write-Host "Установка фиксов для сайта/web-приложения"
    foreach ($apphost in $HostsRS) {
        Write-Host "начинаем обновление на хосте $($Apphost.ComputerName)" -ForegroundColor Yellow
        pause
        if ($stopIIS) {
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -BackupMode -StopPoolBefore -NetAccount $args[2] -WebAppName $args[3]
            } -ArgumentList "$CTSBuildNet\server", $CTSBuildNet, $cred, $CTSinstance
        } else {
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -BackupMode -NetAccount $args[2] -WebAppName $args[3]
            } -ArgumentList "$CTSBuildNet\server", $CTSBuildNet, $cred, $CTSinstance
        }
    }
    Write-Host "Обновленные файлы скопированы на сайты" -ForegroundColor Green
}

# проводим обновления файлов сервиса синхронизации
if ( Test-Path "$CTSBuild\sync") {
    Write-Host "Установка фиксов для службы/сервиса"
    foreach ($apphost in $HostsRS) {
        Write-Host "начинаем обновление на хосте $($Apphost.ComputerName)" -ForegroundColor Yellow
        pause
        # необходимо остановить выполяемые задания в шедуллере для определенного сервиса
        ForEach ($syncservice in $CTSSyncServices) {
            Set-DevOpsToolsTaskState -TasksPath $CTSSyncTaskPath[$syncservice] -TasksState Off
        }
        # производим циклическую проверку все ли задания остановлены
        $AttentnionFlag = 0
        foreach ($syncservice in $CTSSyncServices) {
            $chkcount = 0
            while (Get-ScheduledTask | Where {$_.TaskPath -contains $CTSSyncTaskPath[$syncservice] -and $_.State -notlike "Disabled"}) {
                $chkcount+=1
                if ($chkcount -le 10) { Wait-Event 10} else { $AttentnionFlag+=1; break }
            }
        }
        if ($AttentnionFlag -ne 0) {
            Write-Host "имеются неотключенные задачи CTS" -ForegroundColor Red
            pause
            Write-Host "перед продолжением убедитесь в их отключении вручную" -ForegroundColor Red
            pause
        }
        # останавливаем службу синхронизации на текущем хосте
        $cmd4run = "Update-DevOpsToolsServiceFix -BuildDir " + "'$CTSBuildNet\sync'"
        $cmd4run += " -BackupDir " + "'$CTSBuildNet'"
        $cmd4run += " -ServiceName " + "'$syncservice' -BackupMode"
        $cmd4run += ' -NetAccount $cred2host '
        if ($stopServiceSync) { $cmd4run += " -StopServiceBefore" }
        Invoke-Command -Session $apphost {
            $cred2host = $args[0];  Invoke-Expression $args[1]
        } -ArgumentList $cred, $cmd4run
    }
    Write-Host "Обновленные файлы скопированы для служб" -ForegroundColor Green
}
Write-Host "выполенние окончено" -ForegroundColor Green
#>

