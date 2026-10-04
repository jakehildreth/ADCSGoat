function Deploy-AGEsc1 {
    <#
    .SYNOPSIS
        Deploys the ESC1 scenario: "Copy of Web Server" with Client
        Authentication added by mistake.

    .DESCRIPTION
        Implements the ESC1 recipe settled in ADCSGoat issue #22, riding the
        shared scenario pipeline (Invoke-AGTemplateScenario, issue #27).

        The clone of the built-in Web Server template gets Client
        Authentication (1.3.6.1.5.5.7.3.2) APPENDED to both
        pKIExtendedKeyUsage and msPKI-Certificate-Application-Policy (existing
        Server Auth preserved), Domain Users granted Read + Enroll layered on
        the copied source DACL, and publication on the selected CA. The Web
        Server source is never written.

    .PARAMETER CAName
        The cn of the enterprise CA to publish to. Optional; autodetected
        when the forest has exactly one enterprise CA.

    .PARAMETER StatePath
        Where the deploy state file lives. Defaults to ADCSGoat.State.xml
        next to the module root.

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .PARAMETER Force
        Replaces an ADCSGoat-owned existing clone without prompting. Required
        for non-interactive redeploy.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with CloneCn, Oid, and
        CompanionOidObjectDN.

    .EXAMPLE
        Deploy-AGEsc1

        Clones Web Server, adds Client Auth, grants Domain Users enroll, and
        publishes on the forest's single CA.

    .EXAMPLE
        Deploy-AGEsc1 -CAName 'LabRootCA1' -Force

        Redeploys against the named CA, replacing any owned clone.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'AD writes gated by the Copy-AGTemplate collision prompt / -Force contract per module precedent.')]
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CAName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$StatePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter()]
        [switch]$Force
    )

    begin {
        if ([string]::IsNullOrEmpty($StatePath)) {
            $StatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ADCSGoat.State.xml'
        }

        $clientAuthOid = '1.3.6.1.5.5.7.3.2'
        $enrollGuid = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'
        $allPropsGuid = [guid]'00000000-0000-0000-0000-000000000000'

        # Recipe: append Client Auth to both EKU attributes, preserving the
        # existing Server Auth value. The v2-only application-policy attribute
        # may be absent on a v1-sourced clone; create it.
        $recipe = {
            param($clone)
            $existingEku = @($clone.Properties['pKIExtendedKeyUsage'] | ForEach-Object { "$_" })
            if ($existingEku -notcontains $clientAuthOid) {
                $clone.Properties['pKIExtendedKeyUsage'].Add($clientAuthOid) | Out-Null
            }

            $existingAp = @($clone.Properties['msPKI-Certificate-Application-Policy'] | ForEach-Object { "$_" })
            if ($existingAp.Count -eq 0) {
                foreach ($v in $existingEku) { $clone.Properties['msPKI-Certificate-Application-Policy'].Add($v) | Out-Null }
                if ($existingEku -notcontains $clientAuthOid) { $clone.Properties['msPKI-Certificate-Application-Policy'].Add($clientAuthOid) | Out-Null }
            } elseif ($existingAp -notcontains $clientAuthOid) {
                $clone.Properties['msPKI-Certificate-Application-Policy'].Add($clientAuthOid) | Out-Null
            }
            $clone.CommitChanges()
        }

        # Rights: Domain Users Read + Enroll, layered on the copied DACL.
        $accessRules = {
            param($domainSid)
            New-Object System.DirectoryServices.ActiveDirectoryAccessRule $domainSid, ([System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight), ([System.Security.AccessControl.AccessControlType]::Allow), $enrollGuid
            New-Object System.DirectoryServices.ActiveDirectoryAccessRule $domainSid, ([System.DirectoryServices.ActiveDirectoryRights]::GenericRead), ([System.Security.AccessControl.AccessControlType]::Allow), $allPropsGuid
        }
    }

    process {
        $pipelineParams = @{
            Scenario        = 'ESC1'
            SourceName      = 'WebServer'
            DestinationName = 'Copy of Web Server'
            Recipe          = $recipe
            AccessRules     = $accessRules
            StatePath       = $StatePath
        }
        if ($PSBoundParameters.ContainsKey('CAName')) { $pipelineParams['CAName'] = $CAName }
        if ($PSBoundParameters.ContainsKey('Server')) { $pipelineParams['Server'] = $Server }
        if ($Force.IsPresent) { $pipelineParams['Force'] = $true }

        Invoke-AGTemplateScenario @pipelineParams
    }
}
