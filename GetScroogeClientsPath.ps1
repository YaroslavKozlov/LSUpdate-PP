$PSsessionOptions = New-PSSessionOption -IncludePortInSPN

if (!($HostsRS)) { $HostsRS=@() }

foreach ($Apphost in $Global:SCClientHosts) { 
    $tempRS = New-PSSession $Apphost -SessionOption $PSsessionOptions 
    Invoke-Command -Session $tempRS { Import-Module LSTools; Import-Module DevOpsTools }
    $HostsRS += $tempRS
}

foreach ($AppHost in $HostsRS) {
    if ($Apphost -eq $env:COMPUTERNAME ) { Install-LStoolsClientUpdate -ClientPathOnly }
    else { Invoke-Command -Session $Apphost -ScriptBlock { Install-LStoolsClientUpdate -ClientPathOnly } }
}