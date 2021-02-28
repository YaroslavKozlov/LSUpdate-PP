Import-Module DevOpsTools
Import-Module LSTools
# режим работы скрипта Start, Stop, Status
#RunMode = "Status"
RunMode = "Start"
#$RunMode = "Stop"
$clearRS = 0 # производить очистку массива Remote-PShell

#--------------------------------------
$PSPHosts=@("vm-app-scrooge1","vm-app-scrooge2") # PSP
$WebPlatformHosts=@("vm-app-scrooge1","vm-app-scrooge2") # Webplatform
$CTSHosts=@("vm-app-cts1","vm-app-cts2") # CTS
$WebBankHosts=@("vm-app-webbank1","vm-app-webbank2") # WebBank
$iTinyADMHosts=@("vm-app-iTiny") # iTiny ADMIN


$PSsessionOptions = New-PSSessionOption -IncludePortInSPN

# проверяем нужно ли пересоздавать объекты с массивами.
if (!($HostsRS)) { $HostsRS=@() }
if (!($HostsRSlist)) { $HostsRSlist=@()  }

foreach ($Apphost in $Global:ScroogeHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
foreach ($Apphost in $WebPlatformHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
foreach ($Apphost in $PSPHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
foreach ($Apphost in $CTSHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
foreach ($Apphost in $WebBankHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
foreach ($Apphost in $Global:iTinyHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
foreach ($Apphost in $iTinyADMHosts) { 
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}

# 1. Комплекс Scrooge
Write-Host "`nОпрос комплекса Scrooge" -ForegroundColor Magenta
Write-Host "------------------------" -ForegroundColor Magenta
foreach ($AppHost in $HostsRS) {
    if ($Global:ScroogeHosts -like $Apphost.ComputerName) {
        if ($RunMode -imatch "status") { 
            Invoke-Command -Session $Apphost -ScriptBlock {
                Get-DevOpsToolsWebAppState -WebAppName Scrooge
                Get-DevOpsToolsWebAppState -WebAppName ScroogeWebServices
            } 
         } elseif ($RunMode -imatch "start") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Start-DevOpsToolsWebApp -WebAppName Scrooge
                Start-DevOpsToolsWebApp -WebAppName ScroogeWebServices
            }
         } elseif ($RunMode -like "stop") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Set-DevOpsToolsWebAppState -WebAppName Scrooge -WebAppState Off
                Set-DevOpsToolsWebAppState -WebAppName ScroogeWebServices -WebAppState Off
            }
         }
    }
}
# 2. Комплекс Webplatform
Write-Host "`nОпрос комплекса Webplatform" -ForegroundColor Magenta
Write-Host "----------------------------" -ForegroundColor Magenta
foreach ($AppHost in $HostsRS) {
    if ($WebPlatformHosts -like $Apphost.ComputerName) {
        if ($RunMode -imatch "status") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Get-DevOpsToolsWebAppState -WebAppName WebPlatform
                Get-DevOpsToolsWebAppState -WebAppName WebPlatform.Abank
                Get-DevOpsToolsWebAppState -WebAppName WebPlatform.IdentityServer
            }        
        } elseif ($RunMode -like "start") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Start-DevOpsToolsWebApp -WebAppName WebPlatform
                Start-DevOpsToolsWebApp -WebAppName WebPlatform.Abank
                Start-DevOpsToolsWebApp -WebAppName WebPlatform.IdentityServer
            }
        } elseif ($RunMode -like "stop") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Set-DevOpsToolsWebAppState -WebAppName WebPlatform -WebAppState Off
                Set-DevOpsToolsWebAppState -WebAppName WebPlatform.Abank -WebAppState Off
                Set-DevOpsToolsWebAppState -WebAppName WebPlatform.IdentityServer -WebAppState Off
            }
        }
    }
}
# 3. Комплекс PSP
Write-Host "`nОпрос комплекса PSP" -ForegroundColor Magenta
Write-Host "---------------------" -ForegroundColor Magenta
foreach ($AppHost in $HostsRS) {
    if ($PSPHosts -like $Apphost.ComputerName) {
        if ($RunMode -imatch "status") {
            Invoke-Command -Session $Apphost -ScriptBlock { Get-DevOpsToolsWebAppState -WebAppName PSP }        
        } elseif ($RunMode -imatch "start") {
            Invoke-Command -Session $Apphost -ScriptBlock { Set-DevOpsToolsWebAppState -WebAppName PSP -WebAppState On } 
        } elseif ($RunMode -like "stop") {
            Invoke-Command -Session $Apphost -ScriptBlock { Set-DevOpsToolsWebAppState -WebAppName PSP -WebAppState Off } 
        }
    }
}
# 4. Комплекс CTS
Write-Host "`nОпрос комплекса CTS" -ForegroundColor Magenta
Write-Host "---------------------" -ForegroundColor Magenta
foreach ($AppHost in $HostsRS) {
    if ($CTSHosts -like $Apphost.ComputerName) {
        if ($RunMode -imatch "status") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Get-DevOpsToolsWebAppState -WebAppName CTSWebApp
                Get-DevOpsToolsServiceState -ServiceName "Lime.Cts.Authorization"
                Get-DevOpsToolsServiceState -ServiceName "Lime.Cts.Synchronization"
                Get-DevOpsToolsServiceState -ServiceName "Lime.CTS.Syncronization_SC"
                Get-DevOpsToolsTaskState -TasksPath "\Lime Systems\CTS-SYNC"
                Get-DevOpsToolsTaskState -TasksPath "\Lime Systems\SC-SYNC"
            }        
        } elseif ($RunMode -like "start") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Start-DevOpsToolsWebApp -WebAppName CTSWebApp
                Start-DevOpsToolsService -ServiceName "Lime.Cts.Authorization"
                Start-DevOpsToolsService -ServiceName "Lime.Cts.Synchronization"
                Start-DevOpsToolsService -ServiceName "Lime.CTS.Syncronization_SC"
                Set-DevOpsToolsTaskState -TasksPath  "\Lime Systems\CTS-SYNC" -TasksState On
                Set-DevOpsToolsTaskState -TasksPath  "\Lime Systems\SC-SYNC" -TasksState On
            }
        } elseif ($RunMode -like "stop") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Set-DevOpsToolsTaskState -TasksPath  "\Lime Systems\CTS-SYNC" -TasksState Off
                Set-DevOpsToolsTaskState -TasksPath  "\Lime Systems\SC-SYNC" -TasksState Off
                Set-DevOpsToolsWebAppState -WebAppName CTSWebApp -WebAppState Off
                Set-DevOpsToolsServiceState -ServiceName "Lime.CTS.Syncronization_SC" -ServiceState Off
                Set-DevOpsToolsServiceState -ServiceName "Lime.Cts.Synchronization" -ServiceState Off
            }
        }
    }
}
# 5. Комплекс WebBank
Write-Host "`nОпрос комплекса WebBank" -ForegroundColor Magenta
Write-Host "-------------------------" -ForegroundColor Magenta
foreach ($AppHost in $HostsRS) {
    if ($WebBankHosts -like $Apphost.ComputerName) {
        if ($RunMode -like "status") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Get-DevOpsToolsWebAppState -WebAppName Webbank
                Get-DevOpsToolsServiceState -ServiceName "LS WebBank Reglament vs Notification Service"
            }        
        } elseif ($RunMode -like "start") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Set-DevOpsToolsWebAppState -WebAppName Webbank -WebAppState On
                Set-DevOpsToolsServiceState -ServiceName "LS WebBank Reglament vs Notification Service" -ServiceState On
            }
        }  elseif ($RunMode -like "stop") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Set-DevOpsToolsWebAppState -WebAppName Webbank -WebAppState Off
                Set-DevOpsToolsServiceState -ServiceName "LS WebBank Reglament vs Notification Service" -ServiceState Off
            }
        }
    }
}
# 6. Комплекс iTiny ADMIN
Write-Host "`nОпрос комплекса iTiny (ADMIN)" -ForegroundColor Magenta
Write-Host "-----------------------------" -ForegroundColor Magenta
foreach ($AppHost in $HostsRS) {
    if ($iTinyADMHosts -like $Apphost.ComputerName) {
        if ($RunMode -like "status") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Get-DevOpsToolsWebAppState -IISsite "iTinyPP"
                Get-DevOpsToolsServiceState -ServiceName "LS.iTiny.Sync"
            }        
        } elseif ($RunMode -like "start") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Set-DevOpsToolsWebAppState -IISsite "iTinyPP" -WebAppState On
                Set-DevOpsToolsServiceState -ServiceName "LS.iTiny.Sync" -ServiceState On
            }
        } elseif ($RunMode -like "stop") {
            Invoke-Command -Session $Apphost -ScriptBlock {
                Set-DevOpsToolsWebAppState -IISsite "iTinyPP" -WebAppState Off
                Set-DevOpsToolsServiceState -ServiceName "LS.iTiny.Sync" -ServiceState Off
            }
        }
    }
}
# 7. Комплекс iTiny (бэки)
Write-Host "`nОпрос комплекса iTiny (пулл)" -ForegroundColor Magenta
Write-Host "-----------------------------" -ForegroundColor Magenta
foreach ($AppHost in $HostsRS) {
    if ($Global:iTinyHosts -like $Apphost.ComputerName) {
        if ($RunMode -imatch "status") {
            Invoke-Command -Session $Apphost -ScriptBlock { Get-DevOpsToolsWebAppState -IISsite "iTinyPP" }        
        } elseif ($RunMode -like "start") {
            Invoke-Command -Session $Apphost -ScriptBlock { Set-DevOpsToolsWebAppState -IISsite "iTinyPP" -WebAppState On }
        } elseif ($RunMode -like "stop") {
            Invoke-Command -Session $Apphost -ScriptBlock { Set-DevOpsToolsWebAppState -IISsite "iTinyPP" -WebAppState Off }
        }
    }
}

#---------------------
if ($clearRS -eq 1) {
    foreach ($Apphost in $HostsRS) { Remove-PSSession $Apphost }
    $HostsRS = @()
    $HostsRSlist = @()
}
exit

