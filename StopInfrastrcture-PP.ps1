# подготовительные установки
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$PS_scr1 = New-PSSession vm-app-scrooge1 -SessionOption $PSsessionOptions #-Credential $credUser 
$PS_scr2 = New-PSSession vm-app-scrooge2 -SessionOption $PSsessionOptions #-Credential $credUser
$PS_screod = New-PSSession vm-app-eod -SessionOption $PSsessionOptions


# останавливаем синхронизацию iTiny
Set-Service -ComputerName vm-app-itiny -Name "LS.iTiny.Sync" -Status Stopped

# останавливем АПП Скрудж
Invoke-Command -Session $PS_scr1 { 
    $IISPool = Get-IISAppPool -Name PSPPool
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name PSPPool}
    $IISPool = Get-IISAppPool -Name ScroogeAppPool
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name ScroogeAppPool}
    $IISPool = Get-IISAppPool -Name ScroogeWebServices
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name ScroogeWebServices}
    $IISPool = Get-IISAppPool -Name WebplatformPool
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name WebplatformPool}
}
Write-Host "VM-APP-SCROOGE1 остановлен" -ForegroundColor Green
Invoke-Command -Session $PS_scr2 { 
    $IISPool = Get-IISAppPool -Name PSPPool
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name PSPPool}
    $IISPool = Get-IISAppPool -Name ScroogeAppPool
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name ScroogeAppPool}
    $IISPool = Get-IISAppPool -Name ScroogeWebServices
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name ScroogeWebServices}
    $IISPool = Get-IISAppPool -Name WebplatformPool
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name WebplatformPool}
}
Write-Host "VM-APP-SCROOGE2 остановлен" -ForegroundColor Green
Invoke-Command -Session $PS_screod { 
    $IISPool = Get-IISAppPool -Name ScroogeAppPool
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name ScroogeAppPool}
    $IISPool = Get-IISAppPool -Name ScroogeWebServices
    if ($IISPool.state -eq "Started") {Stop-WebAppPool -Name ScroogeWebServices}
}
Write-Host "VM-APP-EOD остановлен" -ForegroundColor Green
#
