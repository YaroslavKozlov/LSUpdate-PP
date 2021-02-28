#-----------------------
Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools

$UpdateFolder = ""
$UpdateFolderLocal = ""
$UpdateFolderNet = "\\vm-fs2\LSUpdates"
$DBUpdateRoot = "D:\Install"    # папка для выноса апдейтеров БД
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
<#
$ScroogeHosts=@("vm-app-scrooge1","vm-app-scrooge2","vm-app-eod","vm-reglament","vm-app-webbank1","vm-app-webbank2") # Scrooge
$PSPHosts=@("vm-app-scrooge1","vm-app-scrooge2") # PSP
$ScroogeUpdateHosts=@("vm-app-scrooge1","vm-app-scrooge2") # Scrooge Update hosts
#>

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
#$UpdateFolder = "\\vm-fs2\LSUpdates\Update-DEV-20191111"

<#
$CTS1_install = "\\vm-app-cts1\D`$\Install"
$CTS2_install = "\\vm-app-cts2\D`$\Install"
$SCROOGE1_install = "\\vm-app-scrooge1\D`$\Install\version"
$SCROOGE2_install = "\\vm-app-scrooge2\D`$\Install\version"
$SCROOGEEOD_install = "\\vm-app-eod\C`$\Install\version"
$WEBBANK1_install = "\\vm-app-webbank1\D`$\Install\version"
$WEBBANK2_install = "\\vm-app-webbank2\D`$\Install\version"
#>

<#
$ScroogeRS=@(); 
# открываем удаленные сеансы к серверным хостам с комплексом Скрудж
foreach ($Apphost in $ScroogeHosts) {
    $ScroogeRS += New-PSSession $Apphost -SessionOption $PSsessionOptions -Credential $cred
    Invoke-Command -Session $ScroogeRS[-1] { Import-Module LSTools; Import-Module DevOpsTools }
}
#>


# 1. подготовка CTS
$CTSBuild = Join-Path -Path $UpdateFolder -ChildPath "CTS"
$CTSBuildNet = Join-Path -Path $UpdateFolderNet -ChildPath "CTS"
# проверяем распакована ли сборка (по-компонентно)
if (Test-Path "$CTSBuild\ctsAuthorization*.zip") {
    # есть пакет, проверяем распакован ли он
    if (!(Test-Path "$CTSBuild\CtsAuthorization")) {
        $ZipFile = Get-ChildItem -Path $CTSBuild -Filter ctsAuthorization*.zip | sort LastWriteTime | select -Last 1 | % { $_.FullName }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, "$CTSBuild\CtsAuthorization")
    }
}



if ((Test-Path $CTSBuild\cts*.zip) -and -not(Test-Path $UpdateFolder\cts\cts.zip)) {
    if ( Test-Path "$UpdateFolder\cts\ctsAuthorization*.zip" ) {
        $ZipFile = Get-ChildItem -Path $UpdateFolder -Filter ctsAuthorization*.zip | sort LastWriteTime | select -Last 1 | % { $_.FullName }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, "$UpdateFolder\CTS\CtsAuthorization")
    }
    if ( Test-Path "$UpdateFolder\cts\ctsDatabase*.zip" ) {
        $ZipFile = Get-ChildItem -Path $UpdateFolder\cts -Filter ctsDatabase*.zip | sort LastWriteTime | select -Last 1 | % { $_.FullName }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, "$UpdateFolder\CTS\Setup.Database")
    }
    if ( Test-Path "$UpdateFolder\cts\ctsSynchronization_*.zip" ) {
        $ZipFile = Get-ChildItem -Path $UpdateFolder\cts -Filter ctsSynchronization_*.zip | sort LastWriteTime | select -Last 1 | % { $_.FullName }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, "$UpdateFolder\CTS\CtsSynchronization")
    }
    if ( Test-Path "$UpdateFolder\cts\ctsWeb_*.zip" ) {
        $ZipFile = Get-ChildItem -Path $UpdateFolder\cts -Filter ctsWeb_*.zip | sort LastWriteTime | select -Last 1 | % { $_.FullName }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, "$UpdateFolder\CTS\CtsWeb")
    }
    [System.IO.Compression.ZipFile]::CreateFromDirectory("$UpdateFolder\CTS", "$UpdateFolder\CTS.zip")
    Write-Host "Подготовка архива CTS закончена" -ForegroundColor Green
    # раскладываем по хостам.
    if ( Test-Path "$UpdateFolder\CTS.zip") {
        Copy-Item -Path "$UpdateFolder\CTS.zip" -Destination $CTS1_install\CTS -Force 
        Copy-Item -Path "$UpdateFolder\CTS.zip" -Destination $CTS2_install\CTS -Force 
        Write-Host "Копирование архива CTS закончено" -ForegroundColor Green
    }

} else {
    Write-Host "Подготовка CTS не проводилась" -ForegroundColor Red
}

# 2. Подготовка PSP

if ((Test-Path "$UpdateFolder\psp\psp*.zip") -and -not(Test-Path $UpdateFolder\psp\psp.zip)) {
    Install-LStoolsPSPBuildUnpack -UpdateRootDir $UpdateFolder
    Write-Host "Подготовка архива PSP закончена" -ForegroundColor Green
    pause 
    $PSPRS=@(); 
    # открываем удаленные сеансы к серверным хостам с комплексом PSP
    foreach ($Apphost in $PSPHosts) {
        $PSPRS += New-PSSession $Apphost -SessionOption $PSsessionOptions -Credential $cred
        Invoke-Command -Session $PSPRS[-1] { 
            Import-Module LSTools; Import-Module DevOpsTools 
            Copy-LStoolsPSPBuild -UpdateRootDir $args[0] -InstallLocalDir "D:\install" -BuildPart Any
        } -ArgumentList $UpdateFolder
    }
    foreach ($Apphost in $PSPRS) { Remove-PSSession -Session $Apphost}
    $PSPRS=@()
} else { Write-Host "Подготовка архива PSP не проводилась" -ForegroundColor Red }

<#
# 3. Подготовка Scrooge
if ( Test-Path "$UpdateFolder\sc*.zip") {
    Remove-Item -Path $SCROOGE1_install\sc*.zip -Force
    Remove-Item -Path $SCROOGE2_install\sc*.zip -Force
    Remove-Item -Path $WEBBANK1_install\sc*.zip -Force
    Remove-Item -Path $WEBBANK2_install\sc*.zip -Force
    Remove-Item -Path $SCROOGEEOD_install\sc*.zip -Force
    Copy-Item -Path $UpdateFolder\sc*.zip -Destination $scrooge1_install -Force 
    Copy-Item -Path $UpdateFolder\sc*.zip -Destination $scrooge2_install -Force
    Copy-Item -Path $UpdateFolder\sc*.zip -Destination $SCROOGEEOD_install -Force
    Copy-Item -Path $UpdateFolder\sc*.zip -Destination $WEBBANK1_install -Force
    Copy-Item -Path $UpdateFolder\sc*.zip -Destination $WEBBANK2_install -Force
    Write-Host "Копирование архива Scrooge закончено" -ForegroundColor Green
} else {
    Write-Host "Подготовка Scrooge не проводилась" -ForegroundColor Red
}
#>

# 4. Подготовка Webplatform
if ( Test-Path "$UpdateFolder\WebPlatform*.zip") {
    Remove-Item -Path $SCROOGE1_install\WebPlatform*.zip -Force
    Remove-Item -Path $SCROOGE2_install\WebPlatform*.zip -Force
    Copy-Item -Path "$UpdateFolder\WebPlatform*.zip" -Destination $scrooge1_install -Force 
    Copy-Item -Path "$UpdateFolder\WebPlatform*.zip" -Destination $scrooge2_install -Force 
    Write-Host "Копирование архива WebPlatform закончено" -ForegroundColor Green
} else {
    Write-Host "Подготовка Webplatform не проводилась" -ForegroundColor Red
}

