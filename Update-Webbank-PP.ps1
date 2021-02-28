Add-Type -Assembly 'System.IO.Compression.FileSystem'
Import-Module DevOpsTools
Import-Module LSTools

# ��������� ��������� �������
$StartAfterUpdate = $false  # ��������� �� ����� �� ��������� �������

# ���������� 
$UpdateFolder = ""
$UpdateFolderLocal = ""
$ScriptUpdateFolderNet = $Global:UpdateFolderNet
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$scriptSCspecialHosts = $Global:SCspecialHosts
$scriptScroogeHosts = $global:ScroogeHosts
#$global:WebBankHosts=@("grn2-app-web1","grn2-app-web2") # WebBank
if (!$cred) {$cred = Get-Credential -Message "������ ������ ����� ������" -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)}

# ---- ����������� �������� ����� �������
if (!(Test-Path U:\)) {
    # ��������� ����� � ��������� �� ����� ����� ��� ���������� ����� (���� ����� �������)
    $UpdateDisk = New-Object -ComObject WScript.Network
    $UpdateDisk.MapNetworkDrive( "U:", $ScriptUpdateFolderNet, "false")
} 
if (Test-Path U:\) { $UpdateFolder = "U:\"} else { $UpdateFolder = $ScriptUpdateFolderNet }
$TempStr = Get-ChildItem -Path $UpdateFolder -Filter $global:UpdateByDayTemplate | where {$_.PSIsContainer} | Sort-Object Name | select -Last 1 | % {$_.Name}

$UpdateFolder  = Join-Path -Path $UpdateFolder -ChildPath $TempStr
$ScriptUpdateFolderNet = Join-Path -Path $ScriptUpdateFolderNet -ChildPath $TempStr
#$ScriptUpdateFolderNet = "\\vm-fs2\LSUpdates\Update-PP-20191111"
#$UpdateFolder= $ScriptUpdateFolderNet

$WBankBuild = Join-Path -Path $UpdateFolder -ChildPath "Webbank"
$WBankBuildNet = Join-Path -Path $ScriptUpdateFolderNet -ChildPath "Webbank"

if (!(Test-Path $WBankBuild)) { New-LStoolsLSTree -UpdateRootDir $UpdateFolder; Move-LStoolsLSsoft -UpdateRootDir $UpdateFolder}

#
$WebBankRS=@();
foreach ($Apphost in $global:WebBankHosts) {
    $WebBankRS += New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $WebBankRS[-1] { Import-Module LSTools; Import-Module DevOpsTools }
}

# Webbank update process
#----------------------------------------
<# 1.Prepare auxilary folder
Write-Host "Webbank. ���������� �����: " -ForegroundColor Green
foreach ($apphost in $WebBankRS) {
    if ($Global:WebBankHosts -like $Apphost.ComputerName) {
        Invoke-Command -Session $apphost {
            if (Test-Path "D:\Install\WebBank_old" ) { Remove-Item -Path "D:\Install\WebBank_old" -Force -Recurse}
            if (Test-Path "D:\Install\WRNService_old" ) { Remove-Item -Path "D:\Install\WRNService_old" -Force -Recurse}
            Write-Output $Apphost.ComputerName + " ������ �������"
            New-Item -ItemType Directory -Path "D:\Install" -Name WebBank_old -Force | Out-Null
            New-Item -ItemType Directory -Path "D:\Install" -Name WRNService_old -Force | Out-Null
            Write-Output $Apphost.ComputerName + " ����� �������"
        }
    }
}
pause
#>

#---------------------------------------------------------
# 2. ������������ ���������� �� ������
Write-Host "��������� ����������� ����������."
    foreach ($apphost in $WebBankRS) {
        if ($global:WebBankHosts -like $Apphost.ComputerName) {
            Invoke-Command -Session $apphost { 
                Set-DevOpsToolsServiceState -ServiceName "LS WebBank Reglament vs Notification Service" -ServiceState Off
                Set-DevOpsToolsWebAppState -WebAppName "webbank" -WebAppState Off
            } 
        }
    }

#---------------------------------------------------------
# 3. Create Backup
Write-Host "�������� ������." -ForegroundColor Yellow
foreach ($apphost in $WebBankRS) {
    if ($global:WebBankHosts -like $Apphost.ComputerName) {
        Invoke-Command -Session $apphost { 
            Backup-DevOpsToolsWebApp2 -WebAppName "Webbank" -BackupDir $args[0] -NetAccount $args[1] 
            Backup-DevOpsToolsService -ServiceName "LS WebBank Reglament vs Notification Service" -BackupDir $args[0] -NetAccount $args[1]
        } -ArgumentList $global:WBBackupDir[$Apphost.ComputerName], $cred
    }
}

Write-Host "��������� �������� ������" -ForegroundColor Red
pause
#----------------------------------------------------------
# 4.���������������� ����� ������ 
Write-Host "���������� ������� ����� ����� ������. " 
$ZipFile = Get-ChildItem -Path "$WBankBuild" -Filter wb_v*.zip | sort LastWriteTime | select -Last 1 | % { $_.FullName }
#$TempStr = [io.path]::GetFileNameWithoutExtension($ZipFile)
$WebBankNew = Get-ChildItem -Path $WBankBuild -Filter 'wb_v*' -Attributes D #| where {$_.PSIsContainer -and ($_.name -eq "$TempStr") } 
$WebBankNewPath =  Join-Path $WBankBuild -ChildPath $WebBankNew

if (!$WebBankNew) {
    Write-Host "������������� ������"
    Expand-Archive -Path $ZipFile -DestinationPath $WBankBuild -Force
    $WebBankNew = Get-ChildItem -Path $WBankBuild -Filter 'wb_v*' -Attributes D
    $WebBankNewPath =  Join-Path $WBankBuild -ChildPath $WebBankNew
    Write-Host "����� �� ������� �����������"     
} 
    
Write-Host "���������� �������������... " -NoNewline
Copy-Item -Path "$ScriptUpdateFolderNet\..\����������\*.css" -Destination "$WebBankNewPath\site\css" -Force
Copy-Item -Path "$ScriptUpdateFolderNet\..\����������\*.gif" -Destination "$WebBankNewPath\site\images" -Force
Copy-Item -Path "$ScriptUpdateFolderNet\..\����������\*.png" -Destination "$WebBankNewPath\site\images" -Force 
if ($?) {Write-Host "���������."} else {Write-Host "������." -ForegroundColor Red}

Write-Host "��������� ���������� � ���������� ������" -ForegroundColor Red
pause
#
Write-Host "�������� ���������� ������" -ForegroundColor Red
if (Test-Path "$WebBankNewPath\site") {
# ������������ ����� ������ ����� - �������������.
    $SiteBuildNet = Join-Path $WBankBuildNet -ChildPath ($WebBankNew.Name)
    $SiteBuildNet = Join-Path $SiteBuildNet -ChildPath 'site'
    foreach ($apphost in $WebBankRS) {
        if ($global:WebBankHosts -like $Apphost.ComputerName) {
            Write-Host "�������� ������ �����. $($Apphost.ComputerName)"  -ForegroundColor Cyan
            Invoke-Command -Session $apphost { 
                Update-DevOpsToolsWebApp -SrcInstallDir $args[0] -UpdateRootDir $args[1] -ConfigBackupDir $args[1] -WebAppName 'WebBank' -NetAccount $args[2]
                Set-DevOpsToolsWebAppFolderACL -WebAppName 'Webbank' -SubFolders 'App_Data'
            } -ArgumentList $SiteBuildNet, $WBankBuildNet, $cred
        }
    }
}
Write-Host "���������� ������ ��������" -ForegroundColor Red
pause

Write-Host "�������� ���������� ������" -ForegroundColor Red
if (Test-Path "$WebBankNewPath\service") {
# ������������ ����� ������ WRNService - �������������.
    $ServiceBuildNet = Join-Path $WBankBuildNet -ChildPath ($WebBankNew.Name)
    $ServiceBuildNet = Join-Path $ServiceBuildNet -ChildPath 'Service'
    foreach ($apphost in $WebBankRS) {
        if ($global:WebBankHosts -like $Apphost.ComputerName) {
            Write-Host ("�������� ���������� ������ WRNService. " + $Apphost.ComputerName) -ForegroundColor Cyan
            #Invoke-Command -Session $apphost { Install-LStoolsWebbankService -WebBankBuild $args[0] } -ArgumentList "$WBankBuildNet\$WebBankNew"
            Invoke-Command -Session $Apphost {
                Update-DevOpsToolsService -SrcInstallDir $args[0] -ConfigBackupDir $args[1] -ServiceName 'LS WebBank Reglament vs Notification Service' -NetAccount $args[2]
            } -ArgumentList $ServiceBuildNet, $WBankBuildNet, $cred
        }
    }
}
Write-Host "���������� ������ ��������" -ForegroundColor Red
pause
#
if (Test-Path "$WebBankNewPath\fe\40") {
# ������������ ���������� FE �������� - �������������.
    $ScroogeRS=@();
    if (!($HostsRSlist)) { $HostsRSlist=@() }
    foreach ($Apphost in $scriptScroogeHosts) {
        if ($HostsRSlist -like $Apphost) { Continue }
        $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions
        $ScroogeRS +=  $tempRS
        $HostsRSlist += $Apphost
        Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    }
<#
    foreach ($Apphost in $scriptSCspecialHosts) {
        if ($HostsRSlist -like $Apphost) { Continue }
        $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions
        $ScroogeRS +=  $tempRS
        $HostsRSlist += $Apphost
        Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    }
#>
    Write-Host "�������� ����� FE �� ����� Scrooge" -ForegroundColor Cyan
    $FixBuildNet = Join-Path $WBankBuildNet -ChildPath ($WebBankNew.Name)
    $FixBuildNet = Join-Path $FixBuildNet -ChildPath 'fe\40'
    foreach ($apphost in $ScroogeRS) {
        Invoke-Command -Session $Apphost {
            Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -UpdateRootDir $args[1] -WebAppName 'Scrooge' -NetAccount $args[2]
            Update-DevOpsToolsSiteFix -BuildDir $args[0] -BackupDir $args[1] -UpdateRootDir $args[1] -WebAppName 'ScroogeAPI' -NetAccount $args[2]
        } -ArgumentList $FixBuildNet, $WBankBuildNet, $cred
    }
    foreach ($Apphost in $ScroogeRS) { Remove-PSSession $Apphost }
    $ScroogeRS=$null
}

#�������� �������� ����� ����������
if ($StartAfterUpdate) {
Write-Host "������ ��������� WebBank."  -ForegroundColor Cyan
    foreach ($apphost in $WebBankRS) {
        if ($Global:WebBankHosts -like $Apphost.ComputerName) {
            $objTemp = Get-Service -ComputerName $Apphost.ComputerName -Name "LS WebBank Reglament vs Notification Service"
            if ($objTemp.Status -ne "Running") { 
                Set-Service -ComputerName $Apphost.ComputerName -Name "LS WebBank Reglament vs Notification Service" -Status Running
                Write-Host "������ WRNService �� �����" ($Apphost.ComputerName) -NoNewline
                if ($?) { Write-Host " �������" -ForegroundColor Green } else { Write-Host " ������" -ForegroundColor Red }
            } else { Write-Host "WRNService �� �����" ($Apphost.ComputerName) " ��� �������"  }
            # ������ �����
            Invoke-Command -Session $Apphost { Start-DevOpsToolsIISPool -PoolName $args[0] } -ArgumentList "webbank"
            Write-Host ("��������� ����������������� ����� �� �����. https://"+(($Apphost.ComputerName).Trim())+"/webbank/")
            pause
        }
    }
} 
else { Write-Host "������ ��������� WebBank �� ������������"  -ForegroundColor Cyan }
#
foreach ($apphost in $WebBankRS) { Remove-PSSession -Session $Apphost }
$WebBankRS=$null
#if (Test-Path U:\) { $UpdateDisk.RemoveNetworkDrive( "U:" ) }
Write-Host "���������� ��������." -ForegroundColor Green

