function Deploy-AGEsc4 {
    <#
    .SYNOPSIS
        Deploys the ESC4 scenario: "Test SSL" with testing permissions left in
        place.

    .DESCRIPTION
        Implements the ESC4 recipe settled in ADCSGoat issue #22, riding the
        shared scenario pipeline (Invoke-AGTemplateScenario, issue #27). The
        template itself is deliberately unremarkable - the vulnerability is
        purely the access control grant. Zero attribute overrides; Domain
        Users granted Full Control (GenericAll) layered on the copied source
        DACL; published on the selected CA. The Web Server source is never
        written.

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
        Deploy-AGEsc4

        Clones Web Server to 'Test SSL', grants Domain Users Full Control, and
        publishes on the forest's single CA.

    .EXAMPLE
        Deploy-AGEsc4 -CAName 'LabRootCA1' -Force

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

        $allPropsGuid = [guid]'00000000-0000-0000-0000-000000000000'

        # Rights: Domain Users Full Control (GenericAll), layered on the
        # copied DACL. No recipe: zero attribute overrides.
        $accessRules = {
            param($domainSid)
            New-Object System.DirectoryServices.ActiveDirectoryAccessRule $domainSid, ([System.DirectoryServices.ActiveDirectoryRights]::GenericAll), ([System.Security.AccessControl.AccessControlType]::Allow), $allPropsGuid
        }
    }

    process {
        $pipelineParams = @{
            Scenario        = 'ESC4'
            SourceName      = 'WebServer'
            DestinationName = 'Test SSL'
            AccessRules     = $accessRules
            StatePath       = $StatePath
        }
        if ($PSBoundParameters.ContainsKey('CAName')) { $pipelineParams['CAName'] = $CAName }
        if ($PSBoundParameters.ContainsKey('Server')) { $pipelineParams['Server'] = $Server }
        if ($Force.IsPresent) { $pipelineParams['Force'] = $true }

        Invoke-AGTemplateScenario @pipelineParams
    }
}
