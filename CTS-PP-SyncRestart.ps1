Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
Import-Module DevOpsTools
Import-Module LSTools
# переменные 
Write-Host "Важно! будут произведены следующие операции" -ForegroundColor Yellow
Write-Host "1.отключение заданий в Task Scheduler" -ForegroundColor Yellow
Write-Host "2.остановка служб синхронизации" -ForegroundColor Yellow
Write-Host "3.заспуск служб синхронизации" -ForegroundColor Yellow
Write-Host "4.включение заданий в Task Scheduler" -ForegroundColor Yellow

Pause

#if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName "scrooge\ab"}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$CTSSite = "Default Web Site"
$CTSinstance = "CTSWebApp"
$CTSAuthService = "Lime.Cts.Authorization"
#
$CTSSyncServices = @("Lime.Cts.Synchronization","Lime.CTS.Syncronization_SC")
$CTSSyncTaskPath = @{
    'Lime.Cts.Synchronization' = '\Lime Systems\CTS-SYNC\'
    'Lime.CTS.Syncronization_SC' = '\Lime Systems\SC-SYNC\'
} 
#>
$UpdateFolder = ""
$UpdateFolderLocal = ""
$scriptUpdateFolderNet = $Global:UpdateFolderNet  #"\\vm-fs2\LSUpdates\!"
$UpdateNet = $Global:UpdateFolderNet
$scriptCTSHosts = $Global:CTSHosts
#$scriptCTSHosts = @('grn-app-cts1')

$stopIIS = $false
$stopServiceAuth = $false
$stopServiceSync = $true
#

# проверяем нужно ли пересоздавать объекты с массивами.
if (!($HostsRS)) { $HostsRS=@() }
if (!($HostsRSlist)) { $HostsRSlist=@()  } # оптимизированный перечень хостов, без повторов.


# открываем удаленные сеансы к серверным хостам с комплексом CTS
foreach ($Apphost in $scriptCTSHosts) {
    if ($HostsRSlist -like $Apphost) { Continue }
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
    $HostsRSlist += $Apphost
}
Write-Host "1.отключение заданий в Task Scheduler (до 30 sec)" -ForegroundColor Yellow
pause
# проводим перевод заданий в шедуллере в сотоянии "отключено"
ForEach ($Apphost in $HostsRS) {
    ForEach ($syncservice in $CTSSyncServices) {
        Invoke-Command -Session $Apphost {
            Set-DevOpsToolsTaskState -TasksPath $args[0] -TasksState Off
        } -ArgumentList $CTSSyncTaskPath[$syncservice] #>
    } #ForEach (по службам)
} #ForEach (по хостам)
# производим циклическую проверку все ли задания остановлены
foreach ($Apphost in $HostsRS) {
    $AttentnionFlag = 0
    foreach ($syncservice in $CTSSyncServices) {
        Invoke-Command -Session $Apphost { Confirm-CTSTaskDisabled -JobPath $args[0] } -ArgumentList $CTSSyncTaskPath[$syncservice]
    } #foreach
} #foreach

Write-Host "2.остановка служб синхронизации" -ForegroundColor Yellow
pause

foreach ($Apphost in $HostsRS) {
    ForEach ($syncservice in $CTSSyncServices) {
        Invoke-Command -Session $Apphost {
            Set-DevOpsToolsServiceState -ServiceName $args[0] -ServiceState Off
        } -ArgumentList $syncservice 
    } #foreach
} #foreach
exit
Write-Host "3.запуск служб синхронизации" -ForegroundColor Yellow
pause

foreach ($Apphost in $HostsRS) {
    ForEach ($syncservice in $CTSSyncServices) {
        Invoke-Command -Session $Apphost {
            Set-DevOpsToolsServiceState -ServiceName $args[0] -ServiceState On
        } -ArgumentList $syncservice
    } #foreach
} #foreach

Write-Host "4.включение заданий в Task Scheduler" -ForegroundColor Yellow
pause

foreach ($Apphost in $HostsRS) {
    ForEach ($syncservice in $CTSSyncServices) {
        Invoke-Command -Session $Apphost {
            Set-DevOpsToolsTaskState -TasksPath $args[0] -TasksState On
        } -ArgumentList $CTSSyncTaskPath[$syncservice]
    } #foreach
} #foreach

Write-Host 'Процесс окончен' -ForegroundColor Green
