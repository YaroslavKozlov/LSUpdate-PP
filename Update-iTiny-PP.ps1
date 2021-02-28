#---------------------------------------------------------------
Add-Type -Assembly 'System.IO.Compression.FileSystem'
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
if ($UseAltUpdatePath -eq 1) { $scriptUpdateFolderNet = "\\vm-fs2\LSUpdates\!" } 
else { $scriptUpdateFolderNet = $Global:UpdateFolderNet }

$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$scriptiTinyHosts=$Global:iTinyHosts
#
$IISPoolName = "iTinyPool"
$scriptiTinyInstanceName = $global:iTinyInstanceName
$scriptiTinyServiceName = $global:iTinyServiceName
#
if (!($credUser)) {$credUser = Get-Credential -Message "введите учетные данные" -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)}
if (!($HostsRS)) { $HostsRS=@() }
if (!($HostsRSlist)) { $HostsRSlist=@()  }

# ---- определение корневой папки апдейта
if (!(Test-Path U:\)) {
    # монтируем папку с апдейтами на букву диска для сокращения путей (есть очень длинные)
    New-PSDrive -Name U -PSProvider filesystem -Root "$scriptUpdateFolderNet" -Credential $credUser -ErrorAction SilentlyContinue | Out-Null
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $scriptUpdateFolderNet }
if ($UseAltUpdatePath -ne 1) {
    $TempStr = Get-ChildItem -Path $UpdateFolder -Filter $Global:UpdateByDayTemplate | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
} else { $TempStr = ''}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$ScriptUpdateFolderNet = Join-Path -Path $scriptUpdateFolderNet -ChildPath $TempStr
# 
$iTinyBuild = Join-Path -Path $UpdateFolder -ChildPath "iTiny"
$iTinyBuildNet = Join-Path -Path $ScriptUpdateFolderNet -ChildPath "iTiny"

foreach ($apphost in $scriptiTinyHosts ) {
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
# проверяем наличие папки с обновлениями
if (Test-Path $iTinyBuildNet ) {
    Write-Host "используем для обновления $iTinyBuildNet" -ForegroundColor Magenta; Pause
} else {
    Write-Host "папка $iTinyBuildNet отсутствует" -ForegroundColor Red; pause; exit
}
#----------------------------------------------------------
Write-Host "Распаковываем архив с апдейтом iTiny........" -NoNewline
$ZipFile = Get-ChildItem -Path $iTinyBuild -Filter Version_*.zip | sort LastWriteTime | select -Last 1 | % { $_.FullName }
$BuildFileName = [System.IO.Path]::GetFileNameWithoutExtension($ZipFile)
$NewReleaseFolder = Join-Path $iTinyBuild -ChildPath $BuildFileName
$NewReleaseFolderNet = Join-Path $iTinyBuildNet -ChildPath $BuildFileName
if ((Test-Path $NewReleaseFolder) -and ($ForceUnpackBuild -eq 1)) {Remove-Item -Path $NewReleaseFolder -Recurse -Force}
if (-not(Test-Path $NewReleaseFolder)) { [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, "$iTinyBuildNet\") }
Write-Host " выполено" -ForegroundColor Green
#
Write-Host "Контрольное удаление .config в UPDATE-папке  iTinySyncService" 
$appfiles = Get-ChildItem -Path "$NewReleaseFolder\iTinySyncService\*.config" -Attributes !Directory+!System 
$configlist = @("IBankingWinService.exe.config","connectionStrings.config")
if ($appfiles) {
    # если в выборке есть файлы *.config из определенного списка
    foreach ($appfile in $appfiles) {        
        if ($configlist -contains $appfile.Name ) { 
            Remove-Item -Path $appfile.FullName -Force; 
            Write-Host " удален $($appfile.FullName)" -ForegroundColor Green 
        }
    }
} else {Write-Host " не найдены" -ForegroundColor Red}

#
Write-Host "Контрольное удаление Web.config, connectionStrings.config в UPDATE-папке  iTinyApp" 
$appfiles = Get-ChildItem -Path "$NewReleaseFolder\iTinyApp\*.config" -Attributes !Directory+!System  
$configlist = @("Web.config","connectionStrings.config")
if ($appfiles) {
    # если в выборке есть файлы *.config
    foreach ($appfile in $appfiles) {        
        if ($configlist -contains $appfile.Name) { 
            Remove-Item -Path $appfile.FullName -Force; 
            Write-Host " удален $appfile" -ForegroundColor Green 
        } else {
            Write-Host "оставлен в сборке $appfile" -ForegroundColor Gray
        }
    }
} else {Write-Host " не найдены" -ForegroundColor Red}
#
Write-Host "Проверьте отсутствие  ключевых config файлов"
Pause 

#----------------------------------------------------------
Write-Host "Останавливем сервисы и пуллы" -ForegroundColor Magenta
Write-Host "-----------------------------" -ForegroundColor Magenta
foreach ($apphost in $HostsRS) {
    Invoke-Command -Session $apphost -ScriptBlock { Set-DevOpsToolsServiceState -ServiceName $args[0] -ServiceState Off } `
        -ArgumentList $scriptiTinyServiceName
    Invoke-Command -Session $apphost { Set-DevOpsToolsWebAppState -IISsite $args[0] -WebAppState Off } `
        -ArgumentList $scriptiTinyInstanceName
}

#------------------------------------------------------------------
Write-Host "Делаем бэкапы сайта" -ForegroundColor Magenta
Write-Host "-------------------" -ForegroundColor Magenta
foreach ($apphost in $HostsRS) {
    Invoke-Command -Session $apphost {
        Backup-DevOpsToolsWebApp2 -SiteName $args[1] -BackupDir $args[0] -NetAccount $args[3]
        Backup-DevOpsToolsService -ServiceName $args[2] -BackupDir $args[0] -NetAccount $args[3]
        } -ArgumentList ($global:iTinyBackupDir[$Apphost.ComputerName]), $scriptiTinyInstanceName, $scriptiTinyServiceName, $credUser
}
Write-Host "проверьте наличие бэкапов на хостах" -ForegroundColor Red
Pause

# ------------------------------------
# апдейт БД
#-------------------------------------
if ($PrepareDBUpdate -eq 1) {
    Write-Host "Начинаем апдейт БД" -ForegroundColor Magenta
    Write-Host "------------------" -ForegroundColor Magenta
    Pause
    # копируем на локальный диск папки для апдейта базы
    if (Test-Path D:\Install\iTinyDB) {
        Write-Host "очищаем старую папку апдейта iTinyDB" -NoNewline
        Remove-Item -Path D:\Install\iTinyDB -Recurse -Force 
        if ($?) {Write-Host " выполнено" -ForegroundColor Green} else { Write-Host " ошибка" -ForegroundColor Red}
    }
    Copy-Item -Path $NewReleaseFolder\iTinyDB -Destination D:\Install -Recurse -Force
    Set-DevOpsToolsACL -Path "D:\Install\iTinyDB"

    Write-Host "запустите апдейт базы d:\install\iTinyDB\Setup.exe /ServerName=vm-dbms-itiny /DatabaseName=iTinyPP /IgnoreErrors=No /RewriteNewVersion=Yes" -ForegroundColor Red
    Pause

    if (Test-Path D:\Install\ScroogeSQL) {
        Write-Host "очищаем старую папку апдейта ScroogeSQL" -NoNewline
        Remove-Item -Path D:\Install\ScroogeSQL -Recurse -Force 
        if ($?) {Write-Host " выполнено" -ForegroundColor Green} else { Write-Host " ошибка" -ForegroundColor Red}
    }
    Copy-Item -Path $NewReleaseFolder\ScroogeSQL -Destination D:\Install -Recurse -Force
    Set-DevOpsToolsACL -Path "d:\install\ScroogeSQL"

    Write-Host "запустите апдейт базы d:\install\ScroogeSQL\UpdateSCDB.cmd DBMS-WEBBANK\SCROOGEWB Scrooge" -ForegroundColor Red
    Pause
}


# ------------------------------------
# обновление сайта и службы синхронизации
#-------------------------------------
Write-Host "Начинаем апдейт сайта и службы синхронизации" -ForegroundColor Magenta
Write-host "--------------------------------------------" -ForegroundColor Magenta

foreach ($apphost in $HostsRS) {
    Invoke-Command -Session $apphost {
        Update-DevOpsToolsService -SrcInstallDir $args[0] -ServiceName "LS.iTiny.Sync" -ConfigBackupDir $args[1] -NetAccount $args[2] `
        -NewConfigDir $args[3] -StartAfterUpdate } `
        -ArgumentList (Join-Path -Path $NewReleaseFolderNet -ChildPath "iTinySyncService"), `
        (Join-Path -Path $iTinyBuildNet -ChildPath "backup\service") , $credUser,`
        (Join-Path -Path $iTinyBuildNet -ChildPath "config\service")
     Invoke-Command -Session $apphost {
        Update-DevOpsToolsWebApp -UpdateRootDir $args[3]  -SrcInstallDir $args[0] -SiteName $args[4] -ConfigBackupDir $args[1] -NetAccount $args[2] -IISPoolStart} `
        -ArgumentList (Join-Path -Path $NewReleaseFolderNet -ChildPath "iTinyApp"), `
        (Join-Path -Path $iTinyBuildNet -ChildPath "backup\site"), $credUser, $iTinyBuildNet, $scriptiTinyInstanceName
        # при обновлении сайта новые конфиги будут искаться в подпапке "config\site"
}

#Write-Host "Если нужно проведите дополнительные настройки конфигов" -ForegroundColor Red
Pause

# включение приложений
Write-Host "запускаем сервисы и пуллы" -ForegroundColor Magenta
Write-Host "-----------------------------" -ForegroundColor Magenta
foreach ($apphost in $HostsRS) {
    Invoke-Command -Session $apphost -ScriptBlock { Set-DevOpsToolsServiceState -ServiceName $args[0] -ServiceState On } `
        -ArgumentList $scriptiTinyServiceName
    Invoke-Command -Session $apphost { Set-DevOpsToolsWebAppState -IISsite $args[0] -WebAppState On } `
        -ArgumentList $scriptiTinyInstanceName
}


#-------------------------------------------
#$UpdateDisk.RemoveNetworkDrive("U:")
Remove-PSDrive -Name U -Force -ErrorAction SilentlyContinue
Write-Host "Обновление окончено." -ForegroundColor Green
#---------------------
if ($clearRS -eq 1) {
    foreach ($Apphost in $HostsRS) { Remove-PSSession $Apphost }
    $HostsRS = $null
    $HostsRSlist = $null
}

