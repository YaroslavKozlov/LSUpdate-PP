Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools
# переменные 
Write-Host "Важно! проверить необходимость остановки пулла" -ForegroundColor Yellow

if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName "scrooge\ab"}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$UpdateFolder = ""
$UpdateFolderLocal = ""
$UpdateNet = $global:UpdateFolderNet # "\\grn-fs2\LSUpdates"
$stopIIpool = $true
$UnpackBuild = 0 # автоматическая распаковка сборки в скрипте
$scriptWebPlatformHosts = $Global:WebPlatformHosts
#$scriptWebPlatformHosts = @("grn-app-scrapi4")
#
# ---- определение корневой папки апдейта
if (!(Test-Path U:\)) {
    # монтируем папку с апдейтами на букву диска для сокращения путей (есть очень длинные)
    $UpdateDisk = New-Object -ComObject WScript.Network
    $UpdateDisk.MapNetworkDrive( "U:", $UpdateNet, "false")
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $UpdateNet }
$TempStr = Get-ChildItem -Path $UpdateFolder -Filter $global:UpdateByDayTemplate | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$UpdateNet = Join-Path $UpdateNet -ChildPath $TempStr
#$UpdateFolder = "\\grn-fs2\LSUpdates\Update-DEV-20191111"
#
$WPBuild = Join-Path -Path $UpdateFolder -ChildPath "Webplatform"
$WPBuildNet = Join-Path -Path $UpdateNet -ChildPath "Webplatform"
Write-Host "используем для обновления $WPBuildNet" -ForegroundColor Magenta
pause

# проверяем нужно ли пересоздавать объекты с массивами.
if (!($HostsRS)) { $HostsRS=@() }
if (!($HostsRSlist)) { $HostsRSlist=@()  } # оптимизированный перечень хостов, без повторов.

# проверяем, необходимо-ли распаковывать сборку
Write-Host "проверяем необходимость распаковывать сборку" -ForegroundColor Magenta
pause

if ($UnpackBuild -eq 0) { $intFolderCount = 2} else {$intFolderCount = 0}
if (test-path $WPBuildNet\Lime.WebPlatform) { $intFolderCount += 1}
if (test-path $WPBuildNet\Lime.WebPlatform.Abank) { $intFolderCount += 1}
if ($intFolderCount -lt 2) {
    Get-ChildItem $WPBuildNet  -Filter "Lime.WebPlatform*" -Directory | Remove-Item -Recurse -Force
    $zipWithBuild = Get-ChildItem -Path $WPBuildNet -Filter "WebPlatform_*.zip"
    if ($zipWithBuild) {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipWithBuild.FullName, "$WPBuildNet")
    } 
    else {
        Write-Host "файл со сборкой для установки не найден" -ForegroundColor Red
        exit
    }
} 

# открываем удаленные сеансы к серверным хостам с комплексом Webplatform
foreach ($Apphost in $scriptWebPlatformHosts) {
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}

# удаляем конфиги в папке с исходной сборкой
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
# начинаем перебор хостов
foreach ($apphost in $HostsRS) {
    if ($Apphost.ComputerName -notin $scriptWebPlatformHosts) { Continue }
    Write-Host "начинаем обновление на хосте $($Apphost.ComputerName)" -ForegroundColor Yellow
    pause
    if ($stopIIpool) {
       if (Test-Path "$WPBuild\Lime.WebPlatform") {
            Write-Host "Установка фиксов для сайта/web-приложения WebPlatform"
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -WebAppName "WebPlatform" -BackupMode -StopPoolBefore -NetAccount $args[2]
            } -ArgumentList "$WPBuildNet\Lime.WebPlatform", "$WPBuildNet\backup_Lime.WebPlatform",$cred
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -WebAppName "WebPlatformDEV" -BackupMode -StopPoolBefore -NetAccount $args[2]
            } -ArgumentList "$WPBuildNet\Lime.WebPlatform", "$WPBuildNet\backup_Lime.WebPlatform",$cred
       }
       if (Test-Path "$WPBuild\Lime.WebPlatform.Abank") {
            Write-Host "Установка фиксов для сайта/web-приложения WebPlatform.Abank"
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -WebAppName "WebPlatform.Abank" -BackupMode -StopPoolBefore -NetAccount $args[2]
            } -ArgumentList "$WPBuildNet\Lime.WebPlatform.Abank", "$WPBuildNet\backup_Lime.WebPlatform.Abank",$cred
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -WebAppName "WebPlatformDEV.Abank" -BackupMode -StopPoolBefore -NetAccount $args[2]
            } -ArgumentList "$WPBuildNet\Lime.WebPlatform.Abank", "$WPBuildNet\backup_Lime.WebPlatform.Abank",$cred
       }
    } else {
       if (Test-Path "$WPBuild\Lime.WebPlatform") {
            Write-Host "Установка фиксов для сайта/web-приложения WebPlatform"
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -WebAppName "WebPlatform" -BackupMode -NetAccount $args[2]
            } -ArgumentList "$WPBuildNet\Lime.WebPlatform", "$WPBuildNet\backup_Lime.WebPlatform",$cred
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -WebAppName "WebPlatformDEV" -BackupMode -NetAccount $args[2]
            } -ArgumentList "$WPBuildNet\Lime.WebPlatform", "$WPBuildNet\backup_Lime.WebPlatform",$cred
       }
       if (Test-Path "$WPBuild\Lime.WebPlatform.Abank") {
            Write-Host "Установка фиксов для сайта/web-приложения WebPlatform.Abank"
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -WebAppName "WebPlatform.Abank" -BackupMode -NetAccount $args[2]
            } -ArgumentList "$WPBuildNet\Lime.WebPlatform.Abank", "$WPBuildNet\backup_Lime.WebPlatform.Abank",$cred
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -WebAppName "WebPlatformDEV.Abank" -BackupMode -NetAccount $args[2]
            } -ArgumentList "$WPBuildNet\Lime.WebPlatform.Abank", "$WPBuildNet\backup_Lime.WebPlatform.Abank",$cred
       }
    }
}

Write-Host "выполнение окончено" -ForegroundColor Green

