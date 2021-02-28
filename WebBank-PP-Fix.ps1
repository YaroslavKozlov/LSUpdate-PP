Add-Type -Assembly 'System.IO.Compression.FileSystem'
# ���������� 
$UpdateFolder = ""
$UpdateFolderLocal = ""
$UpdateFolderNet = "\\vm-fs2\LSUpdates"
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
# ����� ��-���������� (�����������)

# ---- ����������� �������� ����� �������
if (!(Test-Path U:\)) {
    # ��������� ����� � ��������� �� ����� ����� ��� ���������� ����� (���� ����� �������)
    $UpdateDisk = New-Object -ComObject WScript.Network
    $UpdateDisk.MapNetworkDrive( "U:", $UpdateFolderNet, "false")
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $UpdateFolderNet }
$TempStr = Get-ChildItem -Path $UpdateFolder -Filter Update-PP-* | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}
$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$UpdateFolderNet  = Join-Path -Path $UpdateFolderNet -ChildPath $TempStr
#$UpdateFolder = "\\vm-fs2\LSUpdates\Update-PP-20191111"
#$UpdateFolderNet = $UpdateFolder
$WebBankbuildNet = Join-Path -Path $UpdateFolderNet -ChildPath "Webbank"

#
if (!$WebbankRS) {
    $WebbankRS=@()
    foreach ($Apphost in $Global:WebBankHosts) { 
        $tempObj = New-PSSession $Apphost -SessionOption $PSsessionOptions
        Invoke-Command -Session $tempObj {
            Import-Module LSTools
            Import-Module DevOpsTools }
        $WebbankRS += $tempObj; $tempObj = $null
    }
}

# Webbank update process
#----------------------------------------
$sitefix = Join-Path -Path $WebBankbuildNet -ChildPath "site"
if (Test-Path $sitefix) {
# ���� ���� ��� �����
    Write-Host "������������� ����� ��� �����" -ForegroundColor Magenta
    Write-Host "-----------------------------" -ForegroundColor Magenta
    foreach ($Apphost in $WebbankRS) {
        Invoke-Command -Session $Apphost -ScriptBlock { Install-LStoolsWebbankSiteFix -WebBankBuild $args[0] -BackupBin } -ArgumentList $WebBankbuildNet
    }
}
$fefix = Join-Path -Path $WebBankbuildNet -ChildPath "fe"
if (Test-Path $fefix) {
    # ���� ���� ��� FE ���������
    Write-Host "������������� ����� FE ���������" -ForegroundColor Magenta
    Write-Host "--------------------------------" -ForegroundColor Magenta
    $ScroogeRS=@(); foreach ($Apphost in $Global:ScroogeHosts) { 
        $tempObj = New-PSSession $Apphost -SessionOption $PSsessionOptions
        Invoke-Command -Session $tempObj {
            Import-Module LSTools
            Import-Module DevOpsTools  }
        $ScroogeRS+= $tempObj; $tempObj = $null }
    foreach ($Apphost in $ScroogeRS) {
        Invoke-Command -Session $Apphost -ScriptBlock {
            Install-LStoolsScroogeFE -WebbankBuildDir $args[0] -WebAppName Scrooge } -ArgumentList $WebBankbuildNet }
        }





exit
<#
# 1.Prepare auxilary folder
# ��������� ������� ����� � ������
Write-Host

Write-Host "Webbank. ���������� �����: " -ForegroundColor Green
foreach ($Apphost in $Global:WebBankHosts) {
    Invoke-Command -ComputerName $Apphost -ScriptBlock {
        if (Test-Path $args[0]\WebBank_new ) { Remove-Item -Path $args[0]\WebBank_new -Force -Recurse }
        if (Test-Path $args[0]\WRNService_new ) { Remove-Item -Path $args[0]\WRNService_new -Force -Recurse}   
        if (Test-Path $args[0]\WebBank_old ) { Remove-Item -Path $args[0]\WebBank_old -Force -Recurse}
        if (Test-Path $args[0]\WRNService_old ) { Remove-Item -Path $args[0]\WRNService_old -Force -Recurse}     
        } -ArgumentList ($global:WBInstallDir[$Apphost])
}
Write-Host "������ �������" -ForegroundColor Green
#
foreach ($Apphost in $Global:WebBankHosts) {
    Invoke-Command -ComputerName $Apphost -ScriptBlock {
        New-Item -ItemType Directory -Path $args[0] -Name WebBank_new -Force 
        New-Item -ItemType Directory -Path $args[0] -Name WRNService_new -Force 
        New-Item -ItemType Directory -Path $args[0] -Name WebBank_old -Force
        New-Item -ItemType Directory -Path $args[0] -Name WRNService_old -Force
        } -ArgumentList ($global:WBInstallDir[$Apphost])
}

Write-Host "����� �������" -ForegroundColor Green
pause
#---------------------------------------------------------
# 2. Create Backup
foreach ($Apphost in $WebbankRS) {
    Invoke-Command -Session $Apphost { New-LStoolsWebbankBackup }
}
<#
Invoke-Command -Session $WebbankRS[0] {
    New-LStoolsWebbankBackup
    #Copy-Item -Path c:\inetpub\wwwroot\WebBank\* -Destination D:\Install\WebBank_old -Force -Recurse
    #Copy-Item -Path c:\WRNService\* -Destination D:\Install\WRNService_old -Force -Recurse
}
if ($?) {Write-Host "���������." -ForegroundColor Green} else {Write-Host "������." -ForegroundColor Red}
#
#Write-Host "�������� ������. VM-APP-WEBBANK2. " -NoNewline
Invoke-Command -Session $WebbankRS[1] {
    New-LStoolsWebbankBackup
    #Copy-Item -Path c:\inetpub\wwwroot\WebBank\* -Destination D:\Install\WebBank_old -Force -Recurse
    #Copy-Item -Path c:\WRNService\* -Destination D:\Install\WRNService_old -Force -Recurse
}
if ($?) {Write-Host "���������." -ForegroundColor Green} else {Write-Host "������." -ForegroundColor Red}

Write-Host "��������� �������� ������" -ForegroundColor Red
pause
#----------------------------------------------------------
# 3.���������������� ����� ������ ��� ����� AM-APP-Webbank1
Write-Host "���������� ������� ����� ����� ������. " -NoNewline
$TempStr = Join-Path -Path $UpdateFolder -ChildPath Webbank
if (!(Test-Path $TempStr)) { 
    New-LStoolsLSTree -UpdateRootDir $UpdateFolder
    Move-LStoolsLSsoft -UpdateRootDir $UpdateFolder
}
$ZipFile = Get-ChildItem -Path $TempStr -Filter wb_v*.zip | sort LastWriteTime | select -Last 1 | % { $_.FullName }
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, "$TempStr\")

$WebBankNew = Get-ChildItem -Path $TempStr -Filter "*" | where {$_.PSIsContainer -and ($_.name -like "wb_v*") } 
$WebBankNewPath = "$TempStr\$WebBankNew"
#
Copy-Item -Path "$UpdateFolder\..\����������\*.css" -Destination "$WebBankNewPath\site\css" -Force
Copy-Item -Path "$UpdateFolder\..\����������\*.gif" -Destination "$WebBankNewPath\site\images" -Force
Copy-Item -Path "$UpdateFolder\..\����������\*.png" -Destination "$WebBankNewPath\site\images" -Force 
if ($?) {Write-Host "���������."} else {Write-Host "������." -ForegroundColor Red}
#
Write-Host "����������� � ������� ������ �������� VM-APP-WEBBANK1. " -NoNewline
Copy-Item -Path "\\vm-app-webbank1\C`$\inetpub\wwwroot\WebBank\*.config" -Destination "$WebBankNewPath\site" -Force 
Copy-Item -Path "\\vm-app-webbank1\C`$\inetpub\wwwroot\WebBank\App_Data" -Destination "$WebBankNewPath\site" -Force
Copy-Item -Path "\\vm-app-webbank1\C`$\WRNService\*.config" -Destination "$WebBankNewPath\Service" -Force
if ($?) {Write-Host "���������." -ForegroundColor Green} else {Write-Host "������." -ForegroundColor Red}
# ---------------------------------------------------------
# 4. ��������� ��������� ��� ������� ��������� Webbank
Write-Host "��������� ����������� ����������."
$WRNservice = Get-Service -ComputerName vm-app-webbank1 -Name "LS WebBank Reglament vs Notification Service"
if ($WRNservice.Status -eq "Running") {
    Set-Service -ComputerName vm-app-webbank1 -Name "LS WebBank Reglament vs Notification Service" -Status Stopped
}
Write-Host "VM-APP-WEBBANK1. WRNService stopped."
Write-Host "VM-APP-WEBBANK1. IIS pool Webbank stopped."
Invoke-Command -Session $PS_webbank1 { Stop-WebAppPool -Name Webbank }
if ($?) {Write-Host "���������." -ForegroundColor Green} else {Write-Host "������." -ForegroundColor Red}
$WRNservice = Get-Service -ComputerName vm-app-webbank2 -Name "LS WebBank Reglament vs Notification Service"
if ($WRNservice.Status -eq "Running") {
    Set-Service -ComputerName vm-app-webbank2 -Name "LS WebBank Reglament vs Notification Service" -Status Stopped
}
Write-Host "VM-APP-WEBBANK2. WRNService stopped."
Write-Host "VM-APP-WEBBANK2. IIS pool Webbank stopped."
Invoke-Command -Session $PS_webbank2 { Stop-WebAppPool -Name Webbank }
if ($?) {Write-Host "���������." -ForegroundColor Green} else {Write-Host "������." -ForegroundColor Red}
#-------------------------------------------------------------
# 5. ���������� ���� ������
Write-Host "����������� �� ��������� ���� ����� DBUpdate " -NoNewline
if (Test-Path D:\Install\DbUpdate) {Remove-Item -Path D:\Install\DbUpdate -Recurse -Force }
Copy-Item -Path "$WebBankNewPath\DBUpdate" -Destination D:\Install -Recurse -Force
if ($?) {Write-Host "���������." -ForegroundColor Green} else {Write-Host "������." -ForegroundColor Red}
Write-Host "���������� ���������: D:\install\DbUpdate\Setup.cmd VM-DBMS-WEBBANK\SCROOGEWB webbank" -ForegroundColor Red
pause
#-------------------------------------------------------------
# 6.������������ ������ � ����� ������� ��
Write-Host "����������� ����� ������ �� ���� VM-APP-WEBBANK1"
Invoke-Command -Session $PS_webbank1 -ScriptBlock {
    Remove-Item C:\inetpub\wwwroot\WebBank\* -Recurse -Force
    Remove-Item C:\WRNService\* -Recurse -Force
}
Copy-Item -Path "$WebBankNewPath\site\*" -Destination "\\vm-app-webbank1\C`$\inetpub\wwwroot\WebBank" -Recurse -Force
Copy-Item -Path "$WebBankNewPath\service\*" -Destination "\\vm-app-webbank1\C`$\WRNService" -Recurse -Force
Remove-Item -Path "$WebBankNewPath\site\App_Data" -Recurse -Force
Set-Service -ComputerName vm-app-webbank1 -Name "LS WebBank Reglament vs Notification Service" -Status Running
Invoke-Command -Session $PS_webbank1 { Start-WebAppPool -Name Webbank }
Write-Host "��������� ����������������� ����� �� �����. https://vm-app-webbank1/webbank/"
pause

# ���������� � ���������� ����� ������ Webbank2
Write-Host "���������������� ������ ��� ����� VM-APP-WEBBANK2. " -NoNewline
Copy-Item -Path "\\vm-app-webbank2\C`$\inetpub\wwwroot\WebBank\*.config" -Destination "$WebBankNewPath\site" -Force 
Copy-Item -Path "\\vm-app-webbank2\C`$\WRNService\*.config" -Destination "$WebBankNewPath\Service" -Force
Copy-Item -Path "\\vm-app-webbank2\C`$\inetpub\wwwroot\WebBank\App_Data" -Destination "$WebBankNewPath\site" -Force
#

Write-Host "����������� ����� ������ �� ���� VM-APP-WEBBANK2"
Invoke-Command -Session $PS_webbank2 -ScriptBlock {
    Remove-Item C:\inetpub\wwwroot\WebBank\* -Recurse -Force
    Remove-Item C:\WRNService\* -Recurse -Force
} 

Copy-Item -Path "$WebBankNewPath\site\*" -Destination "\\vm-app-webbank2\C`$\inetpub\wwwroot\WebBank" -Recurse -Force
Copy-Item -Path "$WebBankNewPath\service\*" -Destination "\\vm-app-webbank2\C`$\WRNService" -Recurse -Force
Remove-Item -Path "$WebBankNewPath\site\App_Data" -Recurse -Force
Set-Service -ComputerName vm-app-webbank2 -Name "LS WebBank Reglament vs Notification Service" -Status Running
Invoke-Command -Session $PS_webbank2 { Start-WebAppPool -Name Webbank }
Write-Host "��������� ����������������� ����� �� �����. https://vm-app-webbank2/webbank/"
pause
# ����������� ������ FE
Write-Host "����������� ������ � ���: " -NoNewline
Copy-Item -Path "$WebBankNewPath\fe\40\Bin\*" -Destination "\\vm-app-webbank1\C`$\Program Files\Lime Systems\AppServer\Scrooge\Scrooge.NET.Application Server\Bin" -Recurse -Force
Copy-Item -Path "$WebBankNewPath\fe\40\Bin\*" -Destination "\\vm-app-webbank2\C`$\Program Files\Lime Systems\AppServer\Scrooge\Scrooge.NET.Application Server\Bin" -Recurse -Force
if ($?) {Write-Host "���������." -ForegroundColor Green} else {Write-Host "������." -ForegroundColor Red}

$UpdateDisk.RemoveNetworkDrive( "U:" )
Remove-PSSession $PS_webbank1
Remove-PSSession $PS_webbank2
Write-Host "���������� ��������." -ForegroundColor Green
#>
