ipconfig|out-null;[Console]::outputEncoding =[System.Text.Encoding]::GetEncoding('cp866')
$IsElevated=$false
foreach ($sid in [Security.Principal.WindowsIdentity]::GetCurrent().Groups) {
    if ($sid.Translate([Security.Principal.SecurityIdentifier]).IsWellKnown([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)) {
        $IsElevated=$true
    }
}
if (-not $IsElevated)
{
 Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList ("-command cd $pwd; " + $MyInvocation.Line)
 exit
}

#$PSSessionOption=New-PSSessionOption -IncludePortInSPN
#Enable-PSRemoting -Force
#$PSsessionTS=New-PSSession -ComputerName VM-TSFARM02
#Remove-PSSession -Session $PSsessionTS

#Get-Process lime.* | WHERE {$_.Path  -imatch "VM-APP-SCROOGE"} | Stop-Process -Force
Get-Process lime.* | Stop-Process -Force
Wait-Event -Timeout 5
Invoke-Item -Path "C:\Program Files (x86)\Lime Systems\SCROOGE-III\Client (VM-APP-SCROOGE1.Scrooge)\Bin\Lime.AppUpdater.Starter.exe"

#$PSsessionTS = New-PSSession vm-tsfarm01 #-SessionOption $PSSessionOption
Invoke-Command -ComputerName vm-tsfarm01 -ScriptBlock {
    Get-Process lime.* | Stop-Process -Force
    Wait-Event -Timeout 5
    Invoke-Item -Path "C:\Program Files (x86)\Lime Systems\SCROOGE-III\Client (VM-APP-SCROOGE4.Scrooge)\Bin\Lime.AppUpdater.Starter.exe"
} 

Invoke-Command -ComputerName vm-tsfarm02 -ScriptBlock {
    Get-Process lime.* | Stop-Process -Force
    Wait-Event -Timeout 5
    Invoke-Item -Path "C:\Program Files (x86)\Lime Systems\SCROOGE-III\Client (VM-APP-SCROOGE1.Scrooge)\Bin\Lime.AppUpdater.Starter.exe"
} 
