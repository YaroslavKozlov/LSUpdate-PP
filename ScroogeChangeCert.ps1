Add-Type -Assembly 'System.IO.Compression.FileSystem'
# переменные 
$UpdateFolder = "\\HA-FS\install$\Lime Systems\Update-PP-20190902"
$DirDST1="\\vm-app-scrooge1\C`$\Program Files (x86)\Lime Systems\SCROOGE-III\Update server (scrooge)\Sc3"
$DirDST2="\\vm-app-scrooge2\C`$\Program Files (x86)\Lime Systems\SCROOGE-III\Update server (scrooge)\Sc3"
#$DirDST3="\\vm-app-eod\C`$\Program Files (x86)\Lime Systems\SCROOGE-III\Update Server(Scrooge)\Sc3"
$ThumbprintOld = "4.9.10.3012"
$ThumbprintNew = "4.9.10.3012"
$CN_Old = "4.9.10.3012."
$CN_New = "4.9.10.3012."

# описание функций
function UpdateConfig {
    param (
        [PARAMETER(Mandatory=$True,Position=0)][String]$ThumbOld,
        [PARAMETER(Mandatory=$True,Position=1)][String]$ThumbNew,
        [PARAMETER(Mandatory=$false,Position=2)][String]$CNOld,
        [PARAMETER(Mandatory=$false,Position=3)][String]$CNNew
    )
    #
    Write-Host "Операции над хосте $DirDST"
    Copy-Item "$DirSrc\Package.bin" -Destination "$DirDST\$AppServerVer\" -Force
    if ($?) {Write-Host "Успешно. Скопирован новый package.bin на $DirDST"}
    else {Write-Host "Ошибка" -ForegroundColor Red -NoNewline; Write-Host " копирования Package.bin на $DirDST"}

    #замена в конфиге номера версии 
    $ScroogeConf = Get-Content $DirDST\..\TasksList.xml
    $LineNum=0; $LineNum2=0
    $LineNum=$ScroogeConf | Select-String -Pattern 'name="Обновление SCROOGE-III"' -SimpleMatch | Select-Object -ExpandProperty 'LineNumber'
    $LineNum2=$ScroogeConf | Select-String -Pattern ('Version value="'+$ShiftVer_old+'"') -SimpleMatch | Select-Object -ExpandProperty 'LineNumber'
    if ($LineNum2 -gt $LineNum) {
            $ScroogeConf=$ScroogeConf -replace ('Version value="'+$ShiftVer_old+'"'),('Version value="'+$ShiftVer_new+'"')
            Set-Content $DirDST\..\TasksList.xml $ScroogeConf -Encoding UTF8
        }
        else {Write-Host "Ошибка сдвижки версии в конфиге" -ForegroundColor Red; exit }
    }

# копируем обновления в папку установки Scrooge
if (Test-Path "$UpdateFolder\sc*.zip" ) {
    Copy-Item -Path "$UpdateFolder\sc*.zip" -Destination "\\vm-app-scrooge1\D`$\Install\version" -Force
    if ($?) {Write-Host "Успешно. Скопированы файлы установки Scrooge на vm-app-scrooge1"}
    else {Write-Host "Ошибка" -ForegroundColor Red -NoNewline; Write-Host " копирования файлов установки Scrooge на vm-app-scrooge1"}
    #
    Copy-Item -Path "$UpdateFolder\sc*.zip" -Destination "\\vm-app-scrooge2\D`$\Install\version" -Force
    if ($?) {Write-Host "Успешно. Скопированы файлы установки Scrooge на vm-app-scrooge2"}
    else {Write-Host "Ошибка" -ForegroundColor Red -NoNewline; Write-Host " копирования файлов установки Scrooge на vm-app-scrooge2"}
    #
    Copy-Item -Path "$UpdateFolder\sc*.zip" -Destination "\\vm-app-eod\C`$\Install\version" -Force
    if ($?) {Write-Host "Успешно. Скопированы файлы установки Scrooge на vm-app-EOD"}
    else {Write-Host "Ошибка" -ForegroundColor Red -NoNewline; Write-Host " копирования файлов установки Scrooge на vm-app-EOD"}
}
# копируем Package.bin на Update сервера.
freshUpdateServer $UpdateFolder $DirDST1
freshUpdateServer $UpdateFolder $DirDST2
freshUpdateServer $UpdateFolder $DirDST3

# запускаем обновление клиентов на терминалках после обновления Package.bin
Enable-PSRemoting -Force
Invoke-Command -ComputerName vm-scrooge-ts1 -ScriptBlock {Get-Process lime.* | WHERE {$_.Path  -imatch "VM-APP-"} | Stop-Process -Force} 
Invoke-Command -ComputerName vm-scrooge-ts1 -ScriptBlock {cmd.exe /C "C:\Program Files (x86)\Lime Systems\SCROOGE-III\Client (VM-APP-SCROOGE1.Scrooge)\Bin\Lime.AppUpdater.Starter.exe"} 
Invoke-Command -ComputerName vm-tsfarm01 -ScriptBlock {Get-Process lime.* | WHERE {$_.Path  -imatch "VM-APP-"} | Stop-Process -Force} 
Invoke-Command -ComputerName vm-tsfarm01 -ScriptBlock {cmd.exe /C "C:\Program Files (x86)\Lime Systems\SCROOGE-III\Client (VM-APP-SCROOGE4.Scrooge)\Bin\Lime.AppUpdater.Starter.exe"} 
Invoke-Command -ComputerName vm-tsfarm02 -ScriptBlock {Get-Process lime.* | WHERE {$_.Path  -imatch "VM-APP-"} | Stop-Process -Force} 
Invoke-Command -ComputerName vm-tsfarm02 -ScriptBlock {cmd.exe /C "C:\Program Files (x86)\Lime Systems\SCROOGE-III\Client (VM-APP-SCROOGE1.Scrooge)\Bin\Lime.AppUpdater.Starter.exe"} 


#Copy-Item -Path -Path "$UpdateFolder\sc*.zip" -Destination "\\vm-app-webbank1\D`$\Install"\
exit
# CTS

if ( Test-Path "$UpdateFolder\CTS.zip") {
    Copy-Item -Path "$UpdateFolder\CTS.zip" -Destination "\\vm-app-cts1\D`$\Install\CTS" -Force 
    Copy-Item -Path "$UpdateFolder\CTS.zip" -Destination "\\vm-app-cts2\D`$\Install\CTS" -Force 
}

