function Remove-AGTemplate {
    <#
    .SYNOPSIS
        Deletes an ADCSGoat-owned template object and its companion OID object.

    .DESCRIPTION
        Removes a pKICertificateTemplate object from the Certificate Templates
        container and, where the deleted object's msPKI-Cert-Template-OID
        identifies a companion msPKI-Enterprise-Oid object under CN=OID,
        removes that companion too. Companion ownership is established by OID
        equality against the owned template being replaced (the companion
        class cannot carry the description marker - its schema has no
        description attribute).

        Callers are responsible for only invoking this on objects already
        confirmed ADCSGoat-owned via the description marker.

    .PARAMETER Name
        The cn of the template object to delete.

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .EXAMPLE
        Remove-AGTemplate -Name 'Copy of Web Server'
    #>
    # ShouldProcess is deliberately not implemented: internal building block
    # whose delete is gated by the caller's (Copy-AGTemplate) collision
    # prompt / -Force contract, matching the module's existing precedent.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Internal building block; AD deletes gated by caller collision contract per module precedent.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    begin {
        Add-Type -AssemblyName System.DirectoryServices

        if ([string]::IsNullOrEmpty($Server)) {
            $Server = [System.Net.Dns]::GetHostEntry($env:LOGONSERVER.TrimStart('\')).HostName
        }

        $rootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/RootDSE")
        $configurationPartition = $rootDSE.configurationNamingContext
        $templatesContainerDN = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$configurationPartition"
    }

    process {
        $dn = "CN=$Name,$templatesContainerDN"
        $path = "LDAP://$Server/$dn"
        if (-not [System.DirectoryServices.DirectoryEntry]::Exists($path)) {
            Write-Verbose "Template '$Name' not present; nothing to remove."
            return
        }

        $existing = New-Object System.DirectoryServices.DirectoryEntry($path)
        $oldOid = "$($existing.Properties['msPKI-Cert-Template-OID'].Value)"
        $existing.DeleteTree()
        $existing.Dispose()
        Write-Verbose "Deleted owned template '$Name'."

        # Remove the old companion OID object, identified by OID equality.
        if (-not [string]::IsNullOrEmpty($oldOid)) {
            $oidContainerDN = "CN=OID,CN=Public Key Services,CN=Services,$configurationPartition"
            $oidContainer = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/$oidContainerDN")
            foreach ($child in @($oidContainer.Children)) {
                if ("$($child.Properties['msPKI-Cert-Template-OID'].Value)" -eq $oldOid) {
                    $child.DeleteTree()
                    Write-Verbose "Deleted companion OID object for '$oldOid'."
                }
                $child.Dispose()
            }
            $oidContainer.Dispose()
        }
    }
}
