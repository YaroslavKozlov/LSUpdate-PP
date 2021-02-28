Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools
# настройка поведения скрипта
$ForceUnpackBuild = 0 # {0/1} производить удаление папки с билдом и повторное разворачивание из архива
$PrepareDBUpdate = 0 # {0/1} производить ли подготовку апдейта для БД
$UseAltUpdatePath = 0 # {0/1} использовать 
$clearRS = 1 # производить очистку массива Remote-PShell

# переменные 
$UpdateFolder = ""
$UpdateFolderLocal = ""
if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$CTSSite = "Default Web Site"
$CTSinstance = "CTSWebApp"
$CTSAuthService = "Lime.Cts.Authorization"
$scriptCTSHosts = $Global:CTSHosts
#
$CTSComponents = @('ctsAuthorization','ctsSynchronization','ctsWeb','SC_Synchronization')
$ExcludeFiles = @('*.cmd','*.config','*.xml')
$CTSSyncServices = @("Lime.Cts.Synchronization","Lime.CTS.Syncronization_SC")
$CTSSyncTaskPath = @{
    'Lime.Cts.Synchronization' = '\Lime Systems\CTS-SYNC\'
    'Lime.CTS.Syncronization_SC' = '\Lime Systems\SC-SYNC\'
} 
#>
#
Write-Host "Важно! проверить наличие архивов со сборками" -ForegroundColor Yellow
#>
Pause
# 
if ($UseAltUpdatePath -eq 1) { $scriptUpdateFolderNet = '\\vm-fs2\LSUpdates\!' } 
else { $scriptUpdateFolderNet = $Global:UpdateFolderNet }

#
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
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $scriptUpdateFolderNet }
if ($UseAltUpdatePath -ne 1) {
    $TempStr = Get-ChildItem -Path $UpdateFolder -Filter $Global:UpdateByDayTemplate | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
} else { $TempStr = ''}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$scriptUpdateFolderNet = Join-Path $scriptUpdateFolderNet -ChildPath $TempStr
#
$CTSBuild = Join-Path -Path $UpdateFolder -ChildPath "CTS"
$CTSBuildNet = Join-Path -Path $scriptUpdateFolderNet -ChildPath "CTS"
if (Test-Path $CTSBuildNet ) {
    Write-Host "используем для обновления $CTSBuildNet" -ForegroundColor Magenta
} else {
    Write-Host "папка $CTSBuildNet отсутствует" -ForegroundColor Red
}
pause
Write-Host "Распаковка сборок, полученных от вендора" -ForegroundColor Yellow
Write-host "проверка наличия сборки для SC_Sycronization" -ForegroundColor Gray
$SC_sync_build = Get-ChildItem -Path $CTSBuild -Filter 'ctsSynchronization_SA*.zip' -File
if ($SC_sync_build) {
    Write-Host "найдена сборка $($SC_sync_build.fullname)"
    Rename-Item -Path $SC_sync_build.fullname -NewName 'SC_Synchronization.zip' -Force 
    Write-Host "переименовали в SC_Synchronization.zip"
} else {
    $SC_sync_build = Get-ChildItem -Path $CTSBuild -Filter 'SC_Synchronization' -Directory
    if ($SC_sync_build) {
        Write-Host "найдена уже распакованная сборка для SC_Sycronization" -ForegroundColor Yellow
    } else {
        Write-Host "сборка для SC_Sycronization не найдена" -ForegroundColor Yellow
    }
}
pause
foreach ($CTSComponent in $CTSComponents) {
    $SubCompotentPath = Join-Path $CTSBuild -ChildPath $CTSComponent
    if ((Test-Path $SubCompotentPath) -and ($ForceUnpackBuild) ) { Remove-Item $SubCompotentPath -Force -Recurse} 
    if (-not (Test-Path $SubCompotentPath)) {
        $SubComponentTemplate = $SubCompotentPath + '*.zip'
        if (-not (Test-Path $SubComponentTemplate)) {
            Write-Host "отсутствует файл со сборкой $SubComponentTemplate" -ForegroundColor Red
            Exit
        }
        # распаковываем архив
        $TempStr = Get-ChildItem -Path $SubComponentTemplate | Sort-Object Name | select -Last 1 | % {$_.FullName}
        Expand-Archive -Path $TempStr -DestinationPath $SubCompotentPath -Force
    } #if
} #foreach

Write-Host "Контрольное удаление ненужных первичных файлов в папках сборок  CTS" 
pause
foreach ($CTSComponent in $CTSComponents) {
    $SubCompotentPath = Join-Path $CTSBuild -ChildPath $CTSComponent
    foreach ($Template4del in $ExcludeFiles) {
        $TempStr = Join-Path -Path $SubCompotentPath -ChildPath $Template4del
        $FilesForDelete = Get-ChildItem -Path $TempStr
        if (-not ($FilesForDelete)) { continue }
        foreach ($File in $FilesForDelete ) {
            Remove-Item $File.FullName -Recurse -Force -ErrorAction Continue
            Write-Host (" "*16 + "удален $($File.FullName)") 
        } #foreach
    } #foreach
} #foreach

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

Write-Host "Останавливаем компоненты инфраструктуры"
pause
# сначала отключаем синхротаски, останавилваем веб-приложение и службу авторизации
 foreach ($apphost in $HostsRS) {
    ForEach ($syncservice in $CTSSyncServices) {
        Invoke-Command -Session $Apphost {Set-DevOpsToolsTaskState -TasksPath $args[0] -TasksState Off} `
        -ArgumentList $CTSSyncTaskPath[$syncservice]
    }
    Invoke-Command -Session $Apphost { 
        Set-DevOpsToolsServiceState -ServiceName 'filebeat' -ServiceState Off
        Set-DevOpsToolsWebAppState -WebAppName  $args[0] -WebAppState Off
        Set-DevOpsToolsServiceState -ServiceName $args[1] -ServiceState Off
    } -ArgumentList $CTSinstance, $CTSAuthService
 } #foreach
# затем проверяем что все синхротаски остановлены, и останавливем службу синхронизации
Write-Host "Проверяем отключение всех заданий CTS в шедуллере"
foreach ($apphost in $HostsRS) {
    # производим циклическую проверку все ли задания остановлены
    foreach ($syncservice in $CTSSyncServices) {
        Invoke-Command -Session $Apphost { Confirm-CTSTaskDisabled -JobPath $args[0] } -ArgumentList $CTSSyncTaskPath[$syncservice] 
        # останавливаем текущую службу синхронизации на текущем хосте
        Invoke-Command -Session $Apphost { Set-DevOpsToolsServiceState -ServiceName $args[0] -ServiceState Off} -ArgumentList $syncservice
    } #foreach (по службам)
} #foreach (по хостам)

Write-Host "Производим бэкап компонент" -ForegroundColor Yellow
pause
foreach ($apphost in $HostsRS) {
    Invoke-Command -Session $Apphost {
        Backup-DevOpsToolsWebApp2 -WebAppName $args[0] -BackupDir $args[1] -NetAccount $args[2] 
        Backup-DevOpsToolsService -ServiceName $args[3] -BackupDir $args[1] -NetAccount $args[2]
    } -ArgumentList $CTSinstance, $Global:CTSBackupDir[$Apphost.ComputerName], $cred, $CTSAuthService
    foreach ($syncservice in $CTSSyncServices) {
        Invoke-Command -Session $Apphost {
            Backup-DevOpsToolsService -ServiceName $args[0] -BackupDir $args[1] -NetAccount $args[2] -LevelUpBeforeBackup 1
        } -ArgumentList $syncservice, $Global:CTSBackupDir[$Apphost.ComputerName], $cred
    } # foreach (по службам синхронизации)
} #foreach (по хостам)

Write-Host "Начинаем процесс апдейта"
pause
foreach ($apphost in $HostsRS) {
     Write-Host "начинаем обновление на хосте $($Apphost.ComputerName)" -ForegroundColor Yellow
     # обновляем веб-службу
     Invoke-Command -Session $Apphost {
        Update-DevOpsToolsWebApp -WebAppName $args[0] -UpdateRootDir $args[1] -SrcInstallDir $args[2] `
        -ConfigBackupDir $args[3] -NetAccount $args[4]
     } -ArgumentList $CTSinstance, $CTSBuildNet, `
     (Join-Path $CTSBuildNet -ChildPath 'ctsWeb'),$CTSBuildNet, $cred
#   обновляем службы (синхронизация + авторизация )
    $TempStr = Join-Path $CTSBuild -ChildPath 'ctsSynchronization'
    if (Test-Path $TempStr) {
        Invoke-Command -Session $Apphost {
            Update-DevOpsToolsService -ServiceName $args[0] -SrcInstallDir $args[1] -NetAccount $args[2] -LevelUpBeforeUpdate 1
            Set-DevOpsToolsServiceFolderACL -ServiceName $args[0] -SubFolders 'TwoTransactions' -Account 'scrooge\iis_scrooge'
        } -ArgumentList $CTSSyncServices[0], $TempStr, $cred
    }
#   для обновления службы Lime.CTS.Syncronization_SC должна быть своя сборка
    $TempStr = Join-Path $CTSBuild -ChildPath 'SC_Synchronization'
    if (Test-Path $TempStr) {
        Invoke-Command -Session $Apphost {
            Update-DevOpsToolsService -ServiceName $args[0] -SrcInstallDir $args[1] -NetAccount $args[2] -LevelUpBeforeUpdate 1
        } -ArgumentList $CTSSyncServices[1], $TempStr, $cred
    }
#    обновляем авторизацию
    $TempStr = Join-Path $CTSBuildNet -ChildPath 'ctsAuthorization'
    if (Test-Path $TempStr) {
        Invoke-Command -Session $Apphost {
            Update-DevOpsToolsService -ServiceName $args[0] -SrcInstallDir $args[1] -NetAccount $args[2]
        } -ArgumentList $CTSAuthService, $TempStr, $cred
    }
     
} #foreach (по хостам)

#
Write-Host "выполенние окончено" -ForegroundColor Green
if ($clearRS -eq 1) {
    foreach ($Apphost in $HostsRS) { Remove-PSSession $Apphost }
    $HostsRS = $null
    $HostsRSlist = $null
}



