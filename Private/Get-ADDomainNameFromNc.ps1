function Get-ADDomainNameFromNc {
    <#
    .SYNOPSIS
        Derives the NetBIOS domain name from the configuration naming context.

    .DESCRIPTION
        Internal helper: 'CN=Configuration,DC=adcs,DC=goat' -> 'ADCS'. Used to
        build the 'DOMAIN\Domain Users' NTAccount for SID resolution in the
        scenario deploys.

        The NetBIOS name lives on the domain's crossRef object in the
        Partitions container, keyed by nCName = the domain's default naming
        context DN.

    .PARAMETER ConfigurationNC
        The forest's configuration naming context.

    .PARAMETER Server
        The domain controller to query. Defaults to the logon server.

    .OUTPUTS
        System.String. The domain's NetBIOS name (e.g. 'ADCS').

    .EXAMPLE
        Get-ADDomainNameFromNc -ConfigurationNC 'CN=Configuration,DC=adcs,DC=goat'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationNC,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    process {
        $serverPrefix = if ($Server) { "LDAP://$Server/" } else { 'LDAP://' }

        $rootDSE = New-Object System.DirectoryServices.DirectoryEntry("${serverPrefix}RootDSE")
        $defaultNC = "$($rootDSE.defaultNamingContext)"

        $partitionsDN = "CN=Partitions,$ConfigurationNC"
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("$serverPrefix$partitionsDN")
        $searcher.Filter = "(&(objectClass=crossRef)(nCName=$defaultNC))"
        $searcher.PropertiesToLoad.Add('nETBIOSName') | Out-Null
        $result = $searcher.FindOne()
        if ($null -eq $result) {
            throw "Could not resolve domain NetBIOS name for '$defaultNC'."
        }
        "$($result.Properties['netbiosname'][0])"
    }
}
