<#
производит обновление приложений в базе данных (выполнятеся по просьбе Орехова Д.)
#>
$SetupApplicationPath = "D:\Install\version\Setup.ApplicationServer"


# ---------------
Set-Location -Path $SetupApplicationPath
.\Lime.ConsoleBatchHost.exe .\Lime.Setup.exe -prmfile="\\HA-FS\auxfile\LimeSystem\ScroogeUpdateAppInDB.prm.xml"