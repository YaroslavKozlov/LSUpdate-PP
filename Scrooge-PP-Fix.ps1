Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools
# ���������� 
Write-Host "�����! ��������� ��������� �������� � ����� SERVER" -ForegroundColor Yellow
Write-Host "�����! ��������� ��������� Scrooge\Repack\package.bin" -ForegroundColor Yellow
Write-Host "�����! ��������� ������������ �������� ������" -ForegroundColor Yellow
Write-Host "�����! ��������� ��������� ���������� DEV-��������" -ForegroundColor Yellow
Pause

$DEVupdate = 1  # 1 - ��������� DEV, 0 - �� ���������
if (!$cred) {$cred = Get-Credential -Message "������ ������ ����� ������" -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN

$UpdateFolder = ""
$UpdateFolderLocal = ""
$scriptUpdateFolderNet = $global:UpdateFolderNet #"\\vm-fs2\LSUpdates"
[string]$ShiftVer_new = "4.14.12.1.5"
#
# ---- ����������� �������� ����� �������
if (!(Test-Path U:\)) {
    # ��������� ����� � ��������� �� ����� ����� ��� ���������� ����� (���� ����� �������)
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
    Write-Host "���������� ��� ���������� $ScroogeBuildNet" -ForegroundColor Magenta
} else {
    Write-Host "����� $ScroogeBuildNet �����������" -ForegroundColor Red
}
pause

# ��������� ������� ������ ��������� � ������������ ������
if (!(Test-Path $ScroogeBuild)) { New-LStoolsLSTree -UpdateRootDir $UpdateFolder; Move-LStoolsLSsoft -UpdateRootDir $UpdateFolder }

$ScroogeRS=@(); 
# ��������� ��������� ������ � ��������� ������ � ���������� ������
foreach ($Apphost in $global:ScroogeHosts) {
    $ScroogeRS += New-PSSession $Apphost -SessionOption $PSsessionOptions -Credential $cred
    Invoke-Command -Session $ScroogeRS[-1] { Import-Module LSTools; Import-Module DevOpsTools }
}

# ��������� ���������� � �������� ��� ������� ��� �������� ������������ �����
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
    Write-Host "����������� ���������� ����������� �� �������" -ForegroundColor Green
} else {
    Write-Host "���������� ������� APP ���������. ��� ����� 'server'" -ForegroundColor Yellow
}

pause
# ��������� ���������� �� �������� (������ Package.bin, ��������� �� ������� ����������, �������� ����� ������, ��������� ��������)
if ( Test-Path $ScroogeBuild\Client) {
    # ���������� ��� ��������� ������ Package.bin
    if (!(Test-Path "$ScroogeBuild\Repack" )) { New-Item -Path "$ScroogeBuild\Repack" -ItemType "directory"; Set-DevOpsToolsACL -Path "$ScroogeBuild\Repack" } 
    #  ��������� ����� ����� Package.bin � ������ Scrooge Update
        foreach ($apphost in $ScroogeRS) {
            if ($global:ScroogeUpdateHosts -like $Apphost.ComputerName) {
                Invoke-Command -SessionOption $PSsessionOptions -ComputerName $Apphost.ComputerName -Credential $cred `
                    { New-LStoolsScroogePackageSave -BuildRootDir $args[0] -NetAccount $args[1] } -ArgumentList $ScroogeBuildNet, $cred
            }
    }
    # ��������� ����� package.bin
    New-LStoolsScroogePackage -ScroogeBuildDir $ScroogeBuild
    pause
    # �������� �� ������ � Update �������� ���� package.bin � �������� ������ � �������� ������� ����������
    foreach ($apphost in $ScroogeRS) {
        if ($ScroogeUpdateHosts -like $Apphost.ComputerName) {
            Invoke-Command -Session $apphost {
                Install-LStoolsScroogePackage -ScroogeBuildDir $args[0] -NetAccount $args[2]
                Write-LStoolsScroogeShiftVer -ScroogeVer $args[1]
            } -ArgumentList $ScroogeBuildNet, $ShiftVer_new, $cred
        }
    }
    pause
    Write-Host "������ ���������� ���������� ��������?" -ForegroundColor Red
    Pause
    # ���������� ����� � �������� ������
    $ClientsUpdateJob=@()
    foreach ($Apphost in $global:SCClientHosts) {
        $clientPath = Join-Path -Path $global:SCClientDir[$Apphost] -ChildPath "Bin\Lime.AppUpdater.Starter.exe"
        Write-Host "�������� ���������� ������� Scrooge �� �����: $Apphost"
        if ($Apphost -eq $env:COMPUTERNAME) { 
            # ���� ���� � �������� ��������� � ������� ������ ���������� ������ ����� �������.
            Get-Process lime.* | Stop-Process -Force
            cmd /C "$clientPath"
            Write-Host "�������� ���������� ������� Scrooge �� �����: $env:COMPUTERNAME" -ForegroundColor Green
        } 
        else {
            $ClientsUpdateJob += Invoke-Command -AsJob -ComputerName $Apphost {
                Get-Process lime.* | Stop-Process -Force
                cmd /C "$($args[0])"
                Write-Host "�������� ���������� ������� Scrooge �� �����: $env:COMPUTERNAME" -ForegroundColor Green
            } -ArgumentList $clientPath | Out-Null
        } #if
    } # foreach �� ������ � ��������� ������
    Write-Host  "���������� ��������� ���� ���������� ������������ ������� �� ������" -ForegroundColor Yellow
    sleep -Seconds 25
    Get-Job

} # if (���� ���������� ���������� �����)

foreach ($apphost in $ScroogeRS) { Remove-PSSession $apphost }
$ScroogeRS=@()
$ClientsUpdateJob=@()

if ($UpdateDisk) { $UpdateDisk.RemoveNetworkDrive( "U:" ) }
Write-Host "������ ��������" -ForegroundColor Green


