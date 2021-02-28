Import-Module DevOpsTools
Import-Module LSTools
Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'

#--------------------------------------
$DBUpdatePath = "D:\Install"  # куда положить апдейтер БД CTS
$clearRS = 0 # производить очистку массива Remote-PShell
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$UpdateFolder = ""
$UpdateFolderLocal = ""
$UpdateFolderNet = "\\vm-fs2\LSUpdates"
# ---- определение корневой папки апдейта
if (!(Test-Path U:\)) {
    # монтируем папку с апдейтами на букву диска для сокращения путей (есть очень длинные)
    $UpdateDisk = New-Object -ComObject WScript.Network
    $UpdateDisk.MapNetworkDrive( "U:", $UpdateFolderNet, "false")
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $UpdateFolderNet }
$TempStr = Get-ChildItem -Path $UpdateFolder -Filter Update-PP-* | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$UpdateFolderNet = Join-Path $UpdateFolderNet -ChildPath $TempStr
# раскомментировать для ручного выбора папки с апдейтом
#$UpdateFolder = "\\vm-fs2\LSUpdates\Update-PP-20200211"
#$UpdateFolderNet = $UpdateFolder

Write-Host "источник сборок папка $UpdateFolderNet" -ForegroundColor Yellow
Pause
if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName "scrooge\ab"}
#
$BuildPath = Join-Path -Path $UpdateFolder -ChildPath "CTS"
$BuildPathNet = Join-Path -Path $UpdateFolderNet -ChildPath "CTS"
# проверяем наличие данных комплекса в определенных папках
if (!(Test-Path $BuildPath)) { New-LStoolsLSTree -UpdateRootDir $UpdateFolder; Move-LStoolsLSsoft -UpdateRootDir $UpdateFolder }
if (!($HostsRS)) { $HostsRS=@() }
if (!($HostsRSlist)) { $HostsRSlist=@()  } # оптимизированный перечень хостов, без повторов.

# производим распаковку архивов сборки
Write-Host "`распаковка новой сборки комплекса CTS" -ForegroundColor Magenta
Write-Host "--------------------------------------" -ForegroundColor Magenta

$Builds = Get-ChildItem -Path $BuildPath -Filter cts*.zip -File
foreach ($file in $Builds) {
    $strTemp = $file.name.substring(0,($file.name.indexof("_")))
    if (!(test-path $BuildPath\$strTemp)) {
        New-Item -Path $BuildPath\$strTemp -ItemType directory -Force -ErrorAction SilentlyContinue | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($file.FullName, "$BuildPath\$strTemp")
        if ($strTemp -eq "ctsDatabase") {
            Copy-Item -Path "$BuildPath\$strTemp" -Destination $DBUpdatePath -Force -Recurse
            Set-DevOpsToolsACL -Path $DBUpdatePath
        }
    }
}
# перебирам списки хостов, формируя итоговый массив удаленных соединений
foreach ($Apphost in $global:CTSAuthHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
foreach ($Apphost in $global:CTSWebHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
foreach ($Apphost in $global:CTSSyncHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
#
Write-Host "Начинаеми апдейт CTSWebApp" -ForegroundColor Magenta
pause
Write-Host "останавливаем и бэкапим АПП-ы" -ForegroundColor Yellow

foreach ($AppHost in $HostsRS) {
    if ($global:CTSWebHosts -like $Apphost.ComputerName) {
        Invoke-Command -Session $Apphost -ScriptBlock {
            #стопаем АПП-ы
            Set-DevOpsToolsWebAppState -WebAppName CTSWebApp -WebAppState Off
            # бэкапим АПП-ы
            Backup-DevOpsToolsWebApp2 -WebAppName CTSWebApp -BackupDir $args[0]
        } -ArgumentList ($global:CTSBackupDir[$Apphost.ComputerName])
    }
}
Write-Host "Обновляем CtsWebApp" -ForegroundColor Yellow
pause
foreach ($AppHost in $HostsRS) {
    if ($global:CTSWebHosts -like $Apphost.ComputerName) {
        Invoke-Command -Session $Apphost -ScriptBlock {
            #обновляем АПП
            Update-DevOpsToolsWebApp -SrcInstallDir (Join-Path $args[0] -ChildPath "ctsWeb") -UpdateRootDir $args[0] -WebAppName "CtsWebApp" `
            -ConfigBackupDir $args[0] -NetAccount $args[1] -RestoreConfigAfterUpdate
        } -ArgumentList $BuildPathNet, $cred
    }
}


