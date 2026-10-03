function New-AGTemplateOid {
    <#
    .SYNOPSIS
        Mints a fresh certificate-template OID under the forest's base arc.

    .DESCRIPTION
        Implements the Microsoft-authentic OID pattern settled in ADCSGoat
        issue #22: read the forest's base OID from the msPKI-Cert-Template-OID
        attribute on CN=OID,CN=Public Key Services,CN=Services,<ConfigNC>,
        append two random numeric segments, and create a companion
        ms-PKI-Enterprise-Oid object under the OID container recording the
        OID-to-display-name mapping that the Certificate Templates MMC snap-in
        and certutil resolve.

        The companion class has no description attribute, so companion
        ownership for teardown/replacement is established by OID equality
        against the owned template object (see Remove-AGTemplate), never by
        inspecting the companion's cn.

    .PARAMETER TemplateName
        The display name the new OID resolves to (the destination template's
        identity).

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .OUTPUTS
        System.String. The freshly minted template OID.

    .EXAMPLE
        $oid = New-AGTemplateOid -TemplateName 'Copy of Web Server'

    .NOTES
        The OID container's schema-mandated cn format is "<numeric>.<32 hex
        chars>" (a sequence number plus a GUID-like hex suffix). The sequence
        number is derived from existing children to keep the format authentic.
    #>
    # ShouldProcess is deliberately not implemented: internal building block
    # whose AD write is gated by the caller's (Copy-AGTemplate) collision
    # prompt / -Force contract, matching the module's existing precedent
    # (New-AGBlankTemplateObject performs direct AD writes without
    # ShouldProcess). The collision prompt, not WhatIf, is the safety gate.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Internal building block; AD writes gated by caller collision contract per module precedent.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplateName,

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
        $oidContainerDN = "CN=OID,CN=Public Key Services,CN=Services,$configurationPartition"
        $oidContainer = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/$oidContainerDN")
    }

    process {
        $forestBase = "$($oidContainer.Properties['msPKI-Cert-Template-OID'].Value)"
        if ([string]::IsNullOrEmpty($forestBase)) {
            $exception = New-Object System.InvalidOperationException("Forest base OID not found at '$oidContainerDN' (msPKI-Cert-Template-OID is empty). Is AD CS installed in this forest?")
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'ForestBaseOidNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $oidContainerDN)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # Two random numeric segments per the observed Microsoft pattern.
        $segment1 = Get-Random -Minimum 10000000 -Maximum 99999999
        $segment2 = Get-Random -Minimum 10000000 -Maximum 99999999
        $templateOid = "$forestBase.$segment1.$segment2"

        # Companion object cn: <seq>.<32 hex chars>, matching existing children.
        $existingSeq = @(
            foreach ($child in $oidContainer.Children) {
                $childName = "$($child.Name)"
                if ($childName -match '^CN=(\d+)\.') { [int]$Matches[1] }
                $child.Dispose()
            }
        )
        $nextSeq = if ($existingSeq.Count -gt 0) { ($existingSeq | Measure-Object -Maximum).Maximum + 1 } else { 1 }
        $hexSuffix = [guid]::NewGuid().ToString('N').ToUpperInvariant()
        $companionCn = "$nextSeq.$hexSuffix"

        $companion = $oidContainer.Children.Add("CN=$companionCn", 'msPKI-Enterprise-Oid')
        $companion.CommitChanges()
        $companion.Properties['displayName'].Value = $TemplateName
        $companion.Properties['msPKI-Cert-Template-OID'].Value = $templateOid
        $companion.CommitChanges()
        $companion.Dispose()
        Write-Verbose "Minted template OID '$templateOid' with companion object 'CN=$companionCn,$oidContainerDN'."

        $oidContainer.Dispose()

        Write-Output ([pscustomobject]@{
            Oid               = $templateOid
            CompanionObjectDN = "CN=$companionCn,$oidContainerDN"
        })
    }
}
