Import-Module DevOpsTools
Import-Module LSTools
Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
ipconfig|out-null;[Console]::outputEncoding =[System.Text.Encoding]::GetEncoding('cp866')
#--------------------------------------
$DBUpdatePath = "D:\Install\Setup.Database"  # куда положить апдейтер БД Скрудж
$clearRS = 1 # производить очистку массива Remote-PShell
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$UpdateFolder = ""
$UpdateFolderLocal = ""
$SCcomponents = @('scSetup','scWeb')
# настройка поведения скрипта
$UseAltUpdatePath = 0 # {0/1} использовать 
$ForceUnpackBuild = 1 # {0/1} производить удаление папки с билдом и повторное разворачивание из архива
# 
if ($UseAltUpdatePath -eq 1) { $scriptUpdateFolderNet = '\\vm-fs2\LSUpdates\!' } 
else { $scriptUpdateFolderNet = $Global:UpdateFolderNet }

# ---- определение корневой папки апдейта
if (!(Test-Path U:\)) {
    # монтируем папку с апдейтами на букву диска для сокращения путей (есть очень длинные)
    $UpdateDisk = New-Object -ComObject WScript.Network
    $UpdateDisk.MapNetworkDrive( "U:", $ScriptUpdateFolderNet, "false")
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $ScriptUpdateFolderNet }
if ($UseAltUpdatePath -ne 1) {
    $TempStr = Get-ChildItem -Path $UpdateFolder -Filter $Global:UpdateByDayTemplate | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
} else { $TempStr = ''}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$ScriptUpdateFolderNet = Join-Path $ScriptUpdateFolderNet -ChildPath $TempStr
if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)}
#
$ScroogeBuild = Join-Path -Path $UpdateFolder -ChildPath "Scrooge"
$ScroogeBuildNet = Join-Path -Path $ScriptUpdateFolderNet -ChildPath "Scrooge"
if (Test-Path $ScroogeBuildNet ) {
    Write-Host "используем для обновления $ScroogeBuildNet" -ForegroundColor Magenta
} else {
    Write-Host "папка $ScroogeBuildNet отсутствует" -ForegroundColor Red
}
Pause
# проверяем наличие данных комплекса в определенных папках
if (!(Test-Path $ScroogeBuild)) { New-LStoolsLSTree -UpdateRootDir $UpdateFolder; Move-LStoolsLSsoft -UpdateRootDir $UpdateFolder }

# проверяем нужно ли пересоздавать объекты с массивами.
if (!($HostsRS)) { $HostsRS=@() }
if (!($HostsRSlist)) { $HostsRSlist=@()  } # оптимизированный перечень хостов, без повторов.

foreach ($Apphost in $Global:ScroogeHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
foreach ($Apphost in $Global:SCspecialHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}

Write-Host "`nПодготовка новой сборки комплекса Scrooge" -ForegroundColor Magenta
Write-Host "-------------------------------------------" -ForegroundColor Magenta

Write-Host "распаковываем сборку" -ForegroundColor Yellow
#
$strCMD = 'Install-LStoolsScroogeBuildUnpack -UpdateRootDir "'+ $ScroogeBuild + '" '
$strCMD += '-TargetRootDir "'+ $ScroogeBuild + '" '
if ($ForceUnpackBuild -eq 1) { $strCMD += ' -Force' }
#Install-LStoolsScroogeBuildUnpack -UpdateRootDir $ScroogeBuild -TargetRootDir $ScroogeBuild 
Invoke-Expression $strCMD
#
$buildzip = Get-ChildItem -Path (Join-Path $ScroogeBuildNet -ChildPath '*.zip')  -Include 'scWeb*'
if (-not $buildzip) {
    Write-Host "отсутствует файл со сборкой WebServices" -ForegroundColor Red
    Return
} else {
    if ($buildzip.Name.StartsWith('scWeb')) {
        if ($ForceUnpackBuild -or !(test-path (Join-Path $ScroogeBuildNet -ChildPath 'WebServices' ) )) {
            Expand-Archive -Path $buildzip.FullName -DestinationPath $ScroogeBuildNet -Force
        } #if нужно распаковать
    } # if есть сборка WebServices
}

Write-Host "останавливаем и бэкапим АПП-ы" -ForegroundColor Yellow

foreach ($AppHost in $HostsRS) {
    if ($Global:ScroogeHosts -like $Apphost.ComputerName) {
        Invoke-Command -Session $Apphost -ScriptBlock {
            #стопаем АПП-ы
            Set-DevOpsToolsWebAppState -WebAppName Scrooge -WebAppState Off
            Set-DevOpsToolsWebAppState -WebAppName ScroogeWebServices -WebAppState Off
            Set-DevOpsToolsWebAppState -WebAppName ScroogeAPI -WebAppState Off
            Set-DevOpsToolsWebAppState -WebAppName ScroogeAPIWebServices -WebAppState Off
            # бэкапим АПП-ы
            Backup-DevOpsToolsWebApp2 -WebAppName Scrooge -BackupDir $args[0] -NetAccount $args[1]
            Backup-DevOpsToolsWebApp2 -WebAppName ScroogeWebServices -BackupDir $args[0] -NetAccount $args[1]
            Backup-DevOpsToolsWebApp2 -WebAppName ScroogeAPI -BackupDir $args[0] -NetAccount $args[1]
            Backup-DevOpsToolsWebApp2 -WebAppName ScroogeAPIWebServices -BackupDir $args[0] -NetAccount $args[1]

        } -ArgumentList ($global:SCBackupDir[$Apphost.ComputerName]), $cred
    }
}
<#
pause
Write-Host "подготавливаем апдейт БД Scrooge" -ForegroundColor Magenta
Write-Host "--------------------------------" -ForegroundColor Magenta

pause
if (Test-Path $DBUpdatePath ) { Remove-Item -Path $DBUpdatePath -Recurse -Force }
New-Item -Path $DBUpdatePath -ItemType Directory -Force
Set-DevOpsToolsACL -Path $DBUpdatePath
Robocopy (Join-Path -Path $ScroogeBuild -ChildPath Setup.Database ) $DBUpdatePath /E /xo /w:3 /r:1 /MT:4 /NDL /NP /NFL /NS /NC /NJH
Write-Host "необходимо на хосте 10.140.17.7 запустить D:\Install\UPDATE_Scrooge_SQL.ps1" -ForegroundColor Cyan
pause
#>

Write-Host "производим апдейт APP Scrooge" -ForegroundColor Magenta
Write-Host "------------------------------" -ForegroundColor Magenta
pause

# апдейтим инстанс для клиентов (с сервером обновлений)
foreach ($AppHost in $HostsRS) {
    if ($Global:ScroogeHosts -like $Apphost.ComputerName) {
        Invoke-Command -Session $Apphost -ScriptBlock {
            Install-LStoolsSCServerUpdate  -BuildRootDir $args[0] -InstallDir $args[1] -InstanceName Scrooge -InstallUpdateServer -UpdateServerName Scroogeapp -NetAccount $args[2]
            Install-LStoolsSCServerUpdate  -BuildRootDir $args[0] -InstallDir $args[1] -InstanceName ScroogeAPI -NetAccount $args[2]
        } -ArgumentList $ScroogeBuildNet,$global:SCInstallDir[$Apphost.ComputerName],$cred
        $strTemp = Join-Path $ScroogeBuildNet -ChildPath 'WebServices'
        Invoke-Command -Session $Apphost -ScriptBlock {
            Update-DevOpsToolsWebApp -SrcInstallDir $args[0] -WebAppName ScroogeWebServices -ConfigBackupDir $args[1] -NetAccount $args[2] 
            Update-DevOpsToolsWebApp -SrcInstallDir $args[0] -WebAppName ScroogeAPIWebServices -ConfigBackupDir $args[1] -NetAccount $args[2] 
        } -ArgumentList $strTemp,$ScroogeBuildNet,$cred
    }
}

<# апдейтим инстанс на спецхостах
Write-Host "производим апдейт APP Scrooge на спец-хостах" -ForegroundColor Magenta
Write-Host "--------------------------------------------" -ForegroundColor Magenta
pause

foreach ($AppHost in $HostsRS) {
    if ($Global:SCspecialHosts -like $Apphost.ComputerName) {
        Invoke-Command -Session $Apphost -ScriptBlock {
            Install-LStoolsSCServerUpdate  -BuildRootDir $args[0] -InstallDir $args[1] -InstanceName Scrooge -InstallUpdateServer -UpdateServerName Scroogeapp -NetAccount $args[2]
        } -ArgumentList $ScroogeBuildNet,$global:SCInstallDir[$Apphost.ComputerName],$cred
        $strTemp = Join-Path $ScroogeBuildNet -ChildPath 'WebServices'
        Invoke-Command -Session $Apphost -ScriptBlock {
            Update-DevOpsToolsWebApp -SrcInstallDir $args[0] -WebAppName ScroogeWebServices -ConfigBackupDir $args[1] -NetAccount $args[2] 
        } -ArgumentList $strTemp,$ScroogeBuildNet,$cred
    }
}
#>

# апдейтим клиентские части на терминалках
Write-Host "производим апдейт клента Scrooge" -ForegroundColor Magenta
Write-Host "------------------------------" -ForegroundColor Magenta
pause

foreach ($AppHost in $Global:SCClientHosts) {
    Write-Host "обновляем клиента на хосте $Apphost"
    $clientPath = Join-Path -Path $global:SCClientDir[$Apphost] -ChildPath "Bin\Lime.AppUpdater.Starter.exe"
    if ($env:COMPUTERNAME -eq $Apphost) {
        Get-Process lime.* | Stop-Process -Force
        cmd /C "$clientPath"
    } else {
        Invoke-Command -ComputerName $Apphost -ScriptBlock { Get-Process lime.* | Stop-Process -Force } 
        Invoke-Command -ComputerName $Apphost -ScriptBlock { cmd /C "$($args[0])" } -ArgumentList $clientPath
    }
}

Write-Host "процесс окончен" -ForegroundColor Yellow

#---------------------
if ($clearRS -eq 1) {
    foreach ($Apphost in $HostsRS) { Remove-PSSession $Apphost }
    $HostsRS = $null
    $HostsRSlist = $null
}
