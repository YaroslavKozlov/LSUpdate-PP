Add-Type -Assembly 'System.IO.Compression.FileSystem'
# ���������� 
$UpdateFolder = "\\HA-FS\install$\Lime Systems\Update-PP-20190902"
$DirDST1="\\vm-app-scrooge1\C`$\Program Files (x86)\Lime Systems\SCROOGE-III\Update server (scrooge)\Sc3"
$DirDST2="\\vm-app-scrooge2\C`$\Program Files (x86)\Lime Systems\SCROOGE-III\Update server (scrooge)\Sc3"
#$DirDST3="\\vm-app-eod\C`$\Program Files (x86)\Lime Systems\SCROOGE-III\Update Server(Scrooge)\Sc3"
$ThumbprintOld = "4.9.10.3012"
$ThumbprintNew = "4.9.10.3012"
$CN_Old = "4.9.10.3012."
$CN_New = "4.9.10.3012."

# �������� �������
function UpdateConfig {
    param (
        [PARAMETER(Mandatory=$True,Position=0)][String]$ThumbOld,
        [PARAMETER(Mandatory=$True,Position=1)][String]$ThumbNew,
        [PARAMETER(Mandatory=$false,Position=2)][String]$CNOld,
        [PARAMETER(Mandatory=$false,Position=3)][String]$CNNew
    )
    #
    Write-Host "�������� ��� ����� $DirDST"
    Copy-Item "$DirSrc\Package.bin" -Destination "$DirDST\$AppServerVer\" -Force
    if ($?) {Write-Host "�������. ���������� ����� package.bin �� $DirDST"}
    else {Write-Host "������" -ForegroundColor Red -NoNewline; Write-Host " ����������� Package.bin �� $DirDST"}

    #������ � ������� ������ ������ 
    $ScroogeConf = Get-Content $DirDST\..\TasksList.xml
    $LineNum=0; $LineNum2=0
    $LineNum=$ScroogeConf | Select-String -Pattern 'name="���������� SCROOGE-III"' -SimpleMatch | Select-Object -ExpandProperty 'LineNumber'
    $LineNum2=$ScroogeConf | Select-String -Pattern ('Version value="'+$ShiftVer_old+'"') -SimpleMatch | Select-Object -ExpandProperty 'LineNumber'
    if ($LineNum2 -gt $LineNum) {
            $ScroogeConf=$ScroogeConf -replace ('Version value="'+$ShiftVer_old+'"'),('Version value="'+$ShiftVer_new+'"')
            Set-Content $DirDST\..\TasksList.xml $ScroogeConf -Encoding UTF8
        }
        else {Write-Host "������ ������� ������ � �������" -ForegroundColor Red; exit }
    }

# �������� ���������� � ����� ��������� Scrooge
if (Test-Path "$UpdateFolder\sc*.zip" ) {
    Copy-Item -Path "$UpdateFolder\sc*.zip" -Destination "\\vm-app-scrooge1\D`$\Install\version" -Force
    if ($?) {Write-Host "�������. ����������� ����� ��������� Scrooge �� vm-app-scrooge1"}
    else {Write-Host "������" -ForegroundColor Red -NoNewline; Write-Host " ����������� ������ ��������� Scrooge �� vm-app-scrooge1"}
    #
    Copy-Item -Path "$UpdateFolder\sc*.zip" -Destination "\\vm-app-scrooge2\D`$\Install\version" -Force
    if ($?) {Write-Host "�������. ����������� ����� ��������� Scrooge �� vm-app-scrooge2"}
    else {Write-Host "������" -ForegroundColor Red -NoNewline; Write-Host " ����������� ������ ��������� Scrooge �� vm-app-scrooge2"}
    #
    Copy-Item -Path "$UpdateFolder\sc*.zip" -Destination "\\vm-app-eod\C`$\Install\version" -Force
    if ($?) {Write-Host "�������. ����������� ����� ��������� Scrooge �� vm-app-EOD"}
    else {Write-Host "������" -ForegroundColor Red -NoNewline; Write-Host " ����������� ������ ��������� Scrooge �� vm-app-EOD"}
}
# �������� Package.bin �� Update �������.
freshUpdateServer $UpdateFolder $DirDST1
freshUpdateServer $UpdateFolder $DirDST2
freshUpdateServer $UpdateFolder $DirDST3

# ��������� ���������� �������� �� ����������� ����� ���������� Package.bin
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

