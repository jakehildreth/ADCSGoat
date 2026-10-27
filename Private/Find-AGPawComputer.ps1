function Find-AGPawComputer {
    <#
    .SYNOPSIS
        Finds the lab's privileged access workstation in Active Directory.

    .DESCRIPTION
        Internal helper. Deploy-AGInfrastructure names the workstation
        '<LabName>-PAW', so this searches for computer objects whose name ends
        in '-PAW'. Exactly one match is returned. Zero or several matches throw
        with the candidates listed, so the caller can pass -PawComputerName.

    .PARAMETER Server
        The domain controller to query. Defaults to the logon server.

    .OUTPUTS
        System.String. The workstation's DNS host name, or its name when AD has no DNS host name for it.

    .EXAMPLE
        Find-AGPawComputer -Server dc.adcs.goat
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    Add-Type -AssemblyName System.DirectoryServices

    $serverPrefix = if ($Server) { "LDAP://$Server/" } else { 'LDAP://' }
    $rootDSE = New-Object System.DirectoryServices.DirectoryEntry("${serverPrefix}RootDSE")

    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("$serverPrefix$($rootDSE.defaultNamingContext)")
    $searcher.Filter = '(&(objectCategory=computer)(name=*-PAW))'
    $null = $searcher.PropertiesToLoad.Add('name')
    $null = $searcher.PropertiesToLoad.Add('dnshostname')

    $found = @($searcher.FindAll() | ForEach-Object {
            $hostName = "$($_.Properties['dnshostname'][0])"
            if ($hostName) { $hostName } else { "$($_.Properties['name'][0])" }
        })

    if ($found.Count -ne 1) {
        $detail = if ($found.Count -eq 0) { 'none found' } else { "found $($found -join ', ')" }
        throw "Expected exactly one computer named '*-PAW' ($detail). Pass -PawComputerName."
    }

    $found[0]
}
