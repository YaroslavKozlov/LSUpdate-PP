# переменные 
$PSsessionOptions = New-PSSessionOption -IncludePortInSPN
$CheckedHosts=@("grn-dcmain","grn-dc2","grn-app-scr1","grn-app-scr2","grn-app-scr3","grn-app-scrapi1","grn-app-scrapi2","grn-app-scrapi3","grn-app-web1","grn-app-web2","grn-app-eod","grn-reglament")
$ScroogeRS=@(); 
# открываем удаленные сеансы к проверяемым хостам
foreach ($Apphost in $CheckedHosts) { $ScroogeRS += New-PSSession $Apphost -SessionOption $PSsessionOptions }

Write-Host "Начало опроса: " (Get-Date).ToString()
Write-Host "-------------------------------------"
foreach ($Apphost in $ScroogeRS) {
    Invoke-Command -Session $Apphost  { Write-Host  ($env:COMPUTERNAME).PadRight(20,".")  (Get-Date).ToString() }
}
Write-Host "-------------------------------------"
Write-Host "Окончание опроса: " (Get-Date).ToString()
foreach ($apphost in $ScroogeRS) { Remove-PSSession $apphost }
$ScroogeRS=@()