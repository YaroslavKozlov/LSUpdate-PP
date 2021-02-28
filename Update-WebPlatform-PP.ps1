Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools
# настройка поведения скрипта
$ForceUnpackBuild = 0 # {0/1} производить удаление папки с билдом и повторное разворачивание из архива
$UseAltUpdatePath = 0 # {0/1} использовать 
$clearRS = 1 # производить очистку массива Remote-PShell

# переменные 
Write-Host "Важно! проверить необходимость остановки пулла" -ForegroundColor Yellow
#Pause

if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$UpdateFolder = ""
$UpdateFolderLocal = ""
#$scriptUpdateNet = $Global:Update2FolderNet # "\\grn-fs2\LSUpdates"
$stopIIpool = $true
$scriptWebPlatformHosts = $global:WebPlatformHosts

#$scriptWebPlatformHosts = @("grn-app-scrapi4")
#
# ---- определение корневой папки апдейта
if ($UseAltUpdatePath -eq 1) { $scriptUpdateNet = '\\vm-fs2\LSUpdates\!' } 
else { $scriptUpdateNet = $Global:UpdateFolderNet }

if (!(Test-Path U:\)) {
    # монтируем папку с апдейтами на букву диска для сокращения путей (есть очень длинные)
    $UpdateDisk = New-Object -ComObject WScript.Network
    $UpdateDisk.MapNetworkDrive( "U:", $scriptUpdateNet, "false")
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $scriptUpdateNet }
if ($UseAltUpdatePath -ne 1) {
    $TempStr = Get-ChildItem -Path $UpdateFolder -Filter $global:UpdateByDayTemplate | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
} else { $TempStr = ''}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$scriptUpdateNet = Join-Path $scriptUpdateNet -ChildPath $TempStr
#$UpdateFolder = "\\grn-fs2\LSUpdates\Update-DEV-20191111"
#
$WPBuild = Join-Path -Path $UpdateFolder -ChildPath "Webplatform"
$WPBuildNet = Join-Path -Path $scriptUpdateNet -ChildPath "Webplatform"
if (Test-Path $WPBuildNet ) {
    Write-Host "используем для обновления $WPBuildNet" -ForegroundColor Magenta
} else {
    Write-Host "папка $WPBuildNet отсутствует" -ForegroundColor Red
}
pause
# распаковываем сборку
Write-Host "`nПодготовка новой сборки комплекса Webplatform" -ForegroundColor Magenta
Write-Host "-----------------------------------------------" -ForegroundColor Magenta
Write-Host "распаковываем сборку" -ForegroundColor Yellow

$buildzip = Get-ChildItem -Path (Join-Path $WPBuildNet -ChildPath '*.zip')  -Include 'Webplatform*','Identity*'
if (-not $buildzip) {
    Write-Host "отсутствует файл со сборкой" -ForegroundColor Red
    Return
}
foreach  ($1zip in $buildzip) {
    if ($1zip.Name.StartsWith('WebPlatform_Common')) {
        if ($ForceUnpackBuild -or !(test-path (Join-Path $WPBuildNet -ChildPath 'Lime.WebPlatform' ) )) {
            Expand-Archive -Path $1zip.FullName -DestinationPath $WPBuildNet -Force
        } #if нужно распаковать
    } # if есть сборка WebPlatform
    if ($1zip.Name.StartsWith('WebPlatform_ABank')) {
        if ($ForceUnpackBuild -or !(test-path (Join-Path $WPBuildNet -ChildPath 'Lime.WebPlatform.Abank' ) )) {
            Expand-Archive -Path $1zip.FullName -DestinationPath $WPBuildNet -Force
        } #if нужно распаковать
    } # if есть сборка WebPlatform.Abank
    if ($1zip.Name.StartsWith('Identity')) {
        if ($ForceUnpackBuild -or !(test-path (Join-Path $WPBuildNet -ChildPath 'Lime.IdentityServer' ) )) {
            Expand-Archive -Path $1zip.FullName -DestinationPath $WPBuildNet -Force
        } #if нужно распаковать
    } # if есть сборка IdentityServer
}

# проверяем нужно ли пересоздавать объекты с массивами.
if (!($HostsRS)) { $HostsRS=@() }
if (!($HostsRSlist)) { $HostsRSlist=@()  } # оптимизированный перечень хостов, без повторов.

# открываем удаленные сеансы к серверным хостам с комплексом Webplatform
foreach ($Apphost in $scriptWebPlatformHosts) {
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions -Credential $cred
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}

# удаляем конфиги в папке с исходной сборкой
if ( Test-Path "$WPBuild\Lime.IdentityServer") {
    Write-Host "Контрольное удаление appsettings.json в Build-папке  Lime.IdentityServer"
    $appfiles = Get-ChildItem -Path "$WPBuild\Lime.IdentityServer" -Include appsettings.json -Attributes !Directory+!System -Recurse 
    if ($appfiles) {
        # если в выборке есть файлы appsettings.json
        foreach ($appfile in $appfiles) {        
            if ($appfile.Name -imatch "appsettings.json") { Remove-Item -Path $appfile.FullName -Force; Write-Host " выполнено" -ForegroundColor Green }
        }
    } else {Write-Host " не найдены" -ForegroundColor Red}
}
if ( Test-Path "$WPBuild\Lime.WebPlatform") {
    Write-Host "Контрольное удаление appsettings.json в Build-папке  Lime.WebPlatform"
    $appfiles = Get-ChildItem -Path "$WPBuild\Lime.WebPlatform" -Include appsettings.json -Attributes !Directory+!System -Recurse 
    if ($appfiles) {
        # если в выборке есть файлы appsettings.json
        foreach ($appfile in $appfiles) {        
            if ($appfile.Name -imatch "appsettings.json") { Remove-Item -Path $appfile.FullName -Force; Write-Host " выполнено" -ForegroundColor Green }
        }
    } else {Write-Host " не найдены" -ForegroundColor Red}
}
if ( Test-Path "$WPBuild\Lime.WebPlatform.Abank") {
    Write-Host "Контрольное удаление appsettings.json в Build-папке  Lime.WebPlatform.Abank" 
    $appfiles = Get-ChildItem -Path "$WPBuild\Lime.WebPlatform.Abank" -Include appsettings.json -Attributes !Directory+!System -Recurse 
    if ($appfiles) {
        # если в выборке есть файлы appsettings.json
        foreach ($appfile in $appfiles) {        
            if ($appfile.Name -imatch "appsettings.json") { Remove-Item -Path $appfile.FullName -Force; Write-Host " выполнено" -ForegroundColor Green }
        }
    } else {Write-Host " не найдены" -ForegroundColor Red}
}
#
Write-Host "Производим остановку и бэкап компонент" -ForegroundColor Yellow
pause
foreach ($apphost in $HostsRS) {
     if (Test-Path "$WPBuild\Lime.IdentityServer") {
        Invoke-Command -Session $Apphost {
            Set-DevOpsToolsWebAppState -WebAppName $args[0] -WebAppState Off
            Backup-DevOpsToolsWebApp2 -WebAppName $args[0] -BackupDir $args[1] -NetAccount $args[2] 
        } -ArgumentList 'Webplatform.IdentityServer',$Global:WebPlatformBackupDir[$Apphost.ComputerName],$cred
    } # if нужно бэкапить IdentityServer
    if (Test-Path "$WPBuild\Lime.WebPlatform") {
        Invoke-Command -Session $Apphost {
            Set-DevOpsToolsWebAppState -WebAppName $args[0] -WebAppState Off
            Backup-DevOpsToolsWebApp2 -WebAppName $args[0] -BackupDir $args[1] -NetAccount $args[2] 
        } -ArgumentList 'WebPlatform', $Global:WebPlatformBackupDir[$Apphost.ComputerName], $cred
    } # if нужно бэкапить WebPlatform
    if (Test-Path "$WPBuild\Lime.WebPlatform.Abank") {
        Invoke-Command -Session $Apphost {
            Set-DevOpsToolsWebAppState -WebAppName $args[0] -WebAppState Off
            Backup-DevOpsToolsWebApp2 -WebAppName $args[0] -BackupDir $args[1] -NetAccount $args[2] 
        } -ArgumentList 'WebPlatform.Abank', $Global:WebPlatformBackupDir[$Apphost.ComputerName], $cred
    } # if нужно бэкапить WebPlatform.Abank
}

# начинаем перебор хостов для обновления
foreach ($apphost in $HostsRS) {
    if ($Apphost.ComputerName -notin $scriptWebPlatformHosts) { Continue }
    Write-Host "начинаем обновление на хосте $($Apphost.ComputerName)" -ForegroundColor Yellow
    pause
    # сборка для инстанса IdentityServer
    if (Test-Path "$WPBuild\Lime.IdentityServer\Server") {
        Write-Host "Установка фиксов для сайта/web-приложения IdentityServer"
        Invoke-Command -Session $apphost { 
            $SrcDir = Join-Path $args[1] -ChildPath 'Lime.IdentityServer\Server'
            $BakDir = Join-Path $args[1] -ChildPath 'backup_Lime.IdentityServer'
            if ($args[2]) {
                Update-DevOpsToolsWebApp -SrcInstallDir $SrcDir -UpdateRootDir $args[1] -ConfigBackupDir $BakDir -WebAppName 'Webplatform.IdentityServer' -IISPoolStart -NetAccount $args[0] -ExcludeFiles @('appsettings.json')
            } else {
                Update-DevOpsToolsWebApp -SrcInstallDir $SrcDir -UpdateRootDir $args[1] -ConfigBackupDir $BakDir -WebAppName 'Webplatform.IdentityServer' -NetAccount $args[0] -ExcludeFiles @('appsettings.json')
            }
        } -ArgumentList $cred,$WPBuildNet, $stopIIpool
    } # if есть сборка для инстанса IdentityServer
    # сборка для инстанса WebPlatform
    if (Test-Path "$WPBuild\Lime.WebPlatform") {
        Write-Host "Установка фиксов для сайта/web-приложения WebPlatform"
        Invoke-Command -Session $apphost { 
            $SrcDir = Join-Path $args[1] -ChildPath 'Lime.WebPlatform'
            $BakDir = Join-Path $args[1] -ChildPath 'backup_Lime.WebPlatform'
            if ($args[2]) {
                Update-DevOpsToolsWebApp -SrcInstallDir $SrcDir -UpdateRootDir $args[1] -ConfigBackupDir $BakDir -WebAppName 'Webplatform' -IISPoolStart -NetAccount $args[0] -ExcludeFiles @('appsettings.json')
            } else {
                Update-DevOpsToolsWebApp -SrcInstallDir $SrcDir -UpdateRootDir $args[1] -ConfigBackupDir $BakDir -WebAppName 'Webplatform' -NetAccount $args[0] -ExcludeFiles @('appsettings.json')
            }
        } -ArgumentList $cred,$WPBuildNet, $stopIIpool
    } # if есть сборка для инстанса Webplatform
    # сборка для инстанса WebPlatform.Abank
    if (Test-Path "$WPBuild\Lime.WebPlatform.Abank") {
        Write-Host "Установка фиксов для сайта/web-приложения WebPlatform.Abank"
        Invoke-Command -Session $apphost { 
            $SrcDir = Join-Path $args[1] -ChildPath 'Lime.WebPlatform.Abank'
            $BakDir = Join-Path $args[1] -ChildPath 'backup_Lime.WebPlatform.Abank'
            if ($args[2]) {
                Update-DevOpsToolsWebApp -SrcInstallDir $SrcDir -UpdateRootDir $args[1] -ConfigBackupDir $BakDir -WebAppName 'WebPlatform.Abank' -IISPoolStart -NetAccount $args[0] -ExcludeFiles @('appsettings.json')
            } else {
                Update-DevOpsToolsWebApp -SrcInstallDir $SrcDir -UpdateRootDir $args[1] -ConfigBackupDir $BakDir -WebAppName 'WebPlatform.Abank' -NetAccount $args[0] -ExcludeFiles @('appsettings.json')
            }
        } -ArgumentList $cred,$WPBuildNet,$stopIIpool
    } # if есть сборка для инстанса Webplatform.Abank
}
if (Test-Path U:\) {Remove-PSDrive -Name U -PSProvider FileSystem -Force }
Write-Host "выполнение окончено" -ForegroundColor Green
#---------------------
if ($clearRS -eq 1) {
    foreach ($Apphost in $HostsRS) { Remove-PSSession $Apphost }
    $HostsRS = $null
    $HostsRSlist = $null
}

