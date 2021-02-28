Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools
# переменные 
Write-Host "Важно! проверить структуру подпапок в папке SERVER" -ForegroundColor Yellow
Write-Host "Важно! проверить отсутсвие Scrooge\Repack\package.bin" -ForegroundColor Yellow
Write-Host "Важно! проверить правильность смещения версии" -ForegroundColor Yellow
Write-Host "Важно! проверить включение обновления DEV-инстанса" -ForegroundColor Yellow
Pause

$DEVupdate = 1  # 1 - обновлять DEV, 0 - не обновлять
if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN

$UpdateFolder = ""
$UpdateFolderLocal = ""
$scriptUpdateFolderNet = $global:UpdateFolderNet #"\\vm-fs2\LSUpdates"
[string]$ShiftVer_new = "4.14.12.1.5"
#
# ---- определение корневой папки апдейта
if (!(Test-Path U:\)) {
    # монтируем папку с апдейтами на букву диска для сокращения путей (есть очень длинные)
    $UpdateDisk = New-Object -ComObject WScript.Network
    $UpdateDisk.MapNetworkDrive( "U:", $global:UpdateFolderNet, "false")
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $scriptUpdateFolderNet }
$TempStr = Get-ChildItem -Path $UpdateFolder -Filter $Global:UpdateByDayTemplate | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$scriptUpdateFolderNet = Join-Path $scriptUpdateFolderNet -ChildPath $TempStr
#$UpdateFolder = "\\vm-fs2\LSUpdates\Update-DEV-20191111"
#
$ScroogeBuild = Join-Path -Path $UpdateFolder -ChildPath "Scrooge"
$ScroogeBuildNet = Join-Path -Path $scriptUpdateFolderNet -ChildPath "Scrooge"
if (Test-Path $ScroogeBuildNet ) {
    Write-Host "используем для обновления $ScroogeBuildNet" -ForegroundColor Magenta
} else {
    Write-Host "папка $ScroogeBuildNet отсутствует" -ForegroundColor Red
}
pause

# проверяем наличие данных комплекса в определенных папках
if (!(Test-Path $ScroogeBuild)) { New-LStoolsLSTree -UpdateRootDir $UpdateFolder; Move-LStoolsLSsoft -UpdateRootDir $UpdateFolder }

$ScroogeRS=@(); 
# открываем удаленные сеансы к серверным хостам с комплексом Скрудж
foreach ($Apphost in $global:ScroogeHosts) {
    $ScroogeRS += New-PSSession $Apphost -SessionOption $PSsessionOptions -Credential $cred
    Invoke-Command -Session $ScroogeRS[-1] { Import-Module LSTools; Import-Module DevOpsTools }
}

# обновляем библиотеку в каталоге АПП сервера что вызывает перезагрузку пулла
if ( Test-Path "$ScroogeBuild\Server") {
    foreach ($apphost in $ScroogeRS) {
        Invoke-Command -Session $apphost { Install-LStoolsScroogeServerFix -UpdateRootDir $args[0] -AppName scrooge 
        } -ArgumentList $scriptUpdateFolderNet, $cred
        Invoke-Command -Session $apphost { Install-LStoolsScroogeServerFix -UpdateRootDir $args[0] -AppName scroogeAPI
        } -ArgumentList $scriptUpdateFolderNet, $cred
        
        if ($DEVupdate -eq 1) {
            Invoke-Command -Session $apphost { 
                Install-LStoolsScroogeServerFix -UpdateRootDir $args[0] -AppName scroogedev
                Install-LStoolsScroogeServerFix -UpdateRootDir $args[0] -AppName scroogeAPIdev
            } -ArgumentList $scriptUpdateFolderNet
        }
    }
    Write-Host "Обновленные библиотеки скопированы на серверы" -ForegroundColor Green
} else {
    Write-Host "обновление сервера APP пропущено. Нет папки 'server'" -ForegroundColor Yellow
}

pause
# обновляем библиотеку на клиентах (меняем Package.bin, размещаем на сервере обновлений, изменяем номер версии, обновляем клиентов)
if ( Test-Path $ScroogeBuild\Client) {
    # подготовка для постоения нового Package.bin
    if (!(Test-Path "$ScroogeBuild\Repack" )) { New-Item -Path "$ScroogeBuild\Repack" -ItemType "directory"; Set-DevOpsToolsACL -Path "$ScroogeBuild\Repack" } 
    #  Выполняем бэкап файла Package.bin с хостов Scrooge Update
        foreach ($apphost in $ScroogeRS) {
            if ($global:ScroogeUpdateHosts -like $Apphost.ComputerName) {
                Invoke-Command -SessionOption $PSsessionOptions -ComputerName $Apphost.ComputerName -Credential $cred `
                    { New-LStoolsScroogePackageSave -BuildRootDir $args[0] -NetAccount $args[1] } -ArgumentList $ScroogeBuildNet, $cred
            }
    }
    # формируем новый package.bin
    New-LStoolsScroogePackage -ScroogeBuildDir $ScroogeBuild
    pause
    # заменяем на хостах с Update сервером файл package.bin и сдвигаем версию в конфигах сервера обновлений
    foreach ($apphost in $ScroogeRS) {
        if ($ScroogeUpdateHosts -like $Apphost.ComputerName) {
            Invoke-Command -Session $apphost {
                Install-LStoolsScroogePackage -ScroogeBuildDir $args[0] -NetAccount $args[2]
                Write-LStoolsScroogeShiftVer -ScroogeVer $args[1]
            } -ArgumentList $ScroogeBuildNet, $ShiftVer_new, $cred
        }
    }
    pause
    Write-Host "Начать обновление клиентских программ?" -ForegroundColor Red
    Pause
    # перебираем хосты с клиентом Скрудж
    $ClientsUpdateJob=@()
    foreach ($Apphost in $global:SCClientHosts) {
        $clientPath = Join-Path -Path $global:SCClientDir[$Apphost] -ChildPath "Bin\Lime.AppUpdater.Starter.exe"
        Write-Host "начинаем Обновление клиента Scrooge на хосте: $Apphost"
        if ($Apphost -eq $env:COMPUTERNAME) { 
            # если хост с клиентом совпадает с текущим хостом используем другой метод запуска.
            Get-Process lime.* | Stop-Process -Force
            cmd /C "$clientPath"
            Write-Host "окончили Обновление клиента Scrooge на хосте: $env:COMPUTERNAME" -ForegroundColor Green
        } 
        else {
            $ClientsUpdateJob += Invoke-Command -AsJob -ComputerName $Apphost {
                Get-Process lime.* | Stop-Process -Force
                cmd /C "$($args[0])"
                Write-Host "окончили Обновление клиента Scrooge на хосте: $env:COMPUTERNAME" -ForegroundColor Green
            } -ArgumentList $clientPath | Out-Null
        } #if
    } # foreach по хостам с клиенской частью
    Write-Host  "необходимо подождать пока выполнятся параллельные задания на хостах" -ForegroundColor Yellow
    sleep -Seconds 25
    Get-Job

} # if (есть обновление клиентской части)

foreach ($apphost in $ScroogeRS) { Remove-PSSession $apphost }
$ScroogeRS=@()
$ClientsUpdateJob=@()

if ($UpdateDisk) { $UpdateDisk.RemoveNetworkDrive( "U:" ) }
Write-Host "Работы окончены" -ForegroundColor Green


