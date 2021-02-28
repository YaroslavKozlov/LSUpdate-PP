Add-Type -Assembly 'System.IO.Compression.FileSystem'
Add-Type -assembly 'System.IO.Compression'
# переменные 
if (!$cred) {$cred = Get-Credential -Message "Ведите данные своей учетки" -UserName "scrooge\ab"}
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$JobLogin = 'scrooge\iis_scrooge'
$JobPassword = 'Lime2018'
$scriptCTSHosts = $Global:CTSHosts
$CTSSyncServices = @("Lime.Cts.Synchronization","Lime.CTS.Syncronization_SC")
$CTSSyncTaskPath = @{
    'Lime.Cts.Synchronization' = '\Lime Systems\CTS-SYNC\'
    'Lime.CTS.Syncronization_SC' = '\Lime Systems\SC-SYNC\'
} 
Write-Host "Начинаем переустановку заданий синхронизации в TaskScheduller" -ForegroundColor Yellow
Pause
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

# сначала отключаем синхротаски, удаляем их и создаем заново
 foreach ($apphost in $HostsRS) {
    ForEach ($syncservice in $CTSSyncServices) {
        Invoke-Command -Session $Apphost {Set-DevOpsToolsTaskState -TasksPath $args[0] -TasksState Off} `
        -ArgumentList $CTSSyncTaskPath[$syncservice]
        Install-CTSSyncTaskReinstall -JobPath $CTSSyncTaskPath[$syncservice] -SyncServiceName $syncservice `
        -JobLogin $JobLogin -JobPassword $JobPassword
    } #foreach (по сервисам синхронизации)
 } #foreach (по хостам)


