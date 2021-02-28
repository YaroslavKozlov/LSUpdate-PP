Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools
# настройка поведения скрипта
$ForceUnpackBuild = 0 # {0/1} производить удаление папки с билдом и повторное разворачивание из архива
$UseAltUpdatePath = 0 # {0/1} использовать 
$clearRS = 1 # производить очистку массива Remote-PShell

# переменные 
#Write-Host "Важно! проверить необходимость остановки пулла" -ForegroundColor Yellow
#Pause

if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$UpdateFolder = ""
$UpdateFolderLocal = ""
$scriptUpdateNet = $global:UpdateFolderNet # "\\grn-fs2\LSUpdates"
$stopIIpool = $true
$scriptWebPlatformHosts = $global:WebPlatformHosts

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
#
$PSPBuild = Join-Path -Path $UpdateFolder -ChildPath "PSP"
$PSPBuildNet = Join-Path -Path $scriptUpdateNet -ChildPath "PSP"
if (Test-Path $PSPBuildNet ) {
    Write-Host "используем для обновления $PSPBuildNet" -ForegroundColor Magenta
} else {
    Write-Host "папка $PSPBuildNet отсутствует" -ForegroundColor Red
}
pause
# распаковываем сборку
Write-Host "`nПодготовка новой сборки комплекса PSP" -ForegroundColor Magenta
Write-Host "-----------------------------------------------" -ForegroundColor Magenta
Write-Host "распаковываем сборку" -ForegroundColor Yellow

$buildzip = Get-ChildItem -Path $PSPBuildNet -Filter 'psp*.zip'
if (-not $buildzip) {
    Write-Host "отсутствует файл со сборкой" -ForegroundColor Red
    Return
}
Expand-Archive -Path $buildzip.FullName -DestinationPath "$PSPBuildNet\pspWeb" -Force

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
$pspWebBuils = Join-Path $PSPBuild -ChildPath 'pspWeb'
if ( Test-Path "$pspWebBuils") {
    Write-Host "Контрольное удаление appsettings.json в Build-папке $pspWebBuils"
    $appfiles = Get-ChildItem -Path "$pspWebBuils" -Include appsettings.json -Attributes !Directory+!System -Recurse 
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
    if (Test-Path "$pspWebBuils") {
        Invoke-Command -Session $Apphost {
            Set-DevOpsToolsWebAppState -WebAppName $args[0] -WebAppState Off
            Backup-DevOpsToolsWebApp2 -WebAppName $args[0] -BackupDir $args[1] -NetAccount $args[2] 
        } -ArgumentList 'PSP', $Global:WebPlatformBackupDir[$Apphost.ComputerName], $cred
    }
}

# начинаем перебор хостов
foreach ($apphost in $HostsRS) {
    if ($Apphost.ComputerName -notin $scriptWebPlatformHosts) { Continue }
    Write-Host "начинаем обновление на хосте $($Apphost.ComputerName)" -ForegroundColor Yellow
    pause
    # сборка для инстанса PSPWeb
    if (Test-Path "$pspWebBuils") {
        Write-Host "Установка фиксов для сайта/web-приложения PSPWeb"
        Invoke-Command -Session $apphost { 
            $SrcDir = Join-Path $args[1] -ChildPath 'pspWeb'
            $BakDir = Join-Path $args[1] -ChildPath 'backup_pspWeb'
            Update-DevOpsToolsWebApp -SrcInstallDir $SrcDir -UpdateRootDir $args[1] -ConfigBackupDir $BakDir -WebAppName 'PSP' -NetAccount $args[0] -ExcludeFiles @('appsettings.json')
        } -ArgumentList $cred,"$PSPBuildNet"
    } # if есть сборка для инстанса pspWeb
}
if (Test-Path U:\) {Remove-PSDrive -Name U -PSProvider FileSystem -Force }
Write-Host "выполнение окончено" -ForegroundColor Green
#---------------------
if ($clearRS -eq 1) {
    foreach ($Apphost in $HostsRS) { Remove-PSSession $Apphost }
    $HostsRS = $null
    $HostsRSlist = $null
}

