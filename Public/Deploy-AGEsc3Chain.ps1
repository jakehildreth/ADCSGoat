function Deploy-AGEsc3Chain {
    <#
    .SYNOPSIS
        Deploys the ESC3 enrollment chain: "VMware 6.x" plus the built-in User
        template.

    .DESCRIPTION
        Implements the ESC3 chain settled in ADCSGoat issue #22 (structurally
        ESC3, labelled "ESC2 + schema-v1 User" when scoped), riding the shared
        scenario pipeline (Invoke-AGTemplateScenario, issue #27).

        - VMware 6.x is a clone of the built-in SubCA template with NO EKU
          override: the no-EKU profile satisfies the Certificate-Request-Agent
          check (EKU absence is unrestricted per RFC 5280 4.2.1.12 + CAPI2
          behavior), so nothing is added.
        - Authenticated Users are granted Read + Enroll, layered on the copied
          source DACL.
        - VMware 6.x is published on the selected CA.
        - The built-in User template is published on the selected CA if not
          already published. Its ACL is never changed. Preflight (issue #26)
          already hard-errors if Domain Users cannot enroll through User.
        - VMware 6.x is never added to NTAuthCertificates.

        The SubCA source and the User template are never written; verification
        asserts both are unchanged.

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
        Deploy-AGEsc3Chain

        Clones SubCA to 'VMware 6.x', grants Authenticated Users enroll, and
        publishes both VMware 6.x and the built-in User template.

    .EXAMPLE
        Deploy-AGEsc3Chain -CAName 'LabRootCA1' -Force

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

        $enrollGuid = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'
        $allPropsGuid = [guid]'00000000-0000-0000-0000-000000000000'

        # Rights: Authenticated Users Read + Enroll, layered on the copied
        # DACL. The pipeline resolves the well-known S-1-5-11 SID and passes it
        # in. No recipe: no EKU override (no-EKU profile satisfies the
        # Certificate-Request-Agent check).
        $accessRules = {
            param($principalSid)
            New-Object System.DirectoryServices.ActiveDirectoryAccessRule $principalSid, ([System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight), ([System.Security.AccessControl.AccessControlType]::Allow), $enrollGuid
            New-Object System.DirectoryServices.ActiveDirectoryAccessRule $principalSid, ([System.DirectoryServices.ActiveDirectoryRights]::GenericRead), ([System.Security.AccessControl.AccessControlType]::Allow), $allPropsGuid
        }
    }

    process {
        $pipelineParams = @{
            Scenario             = 'ESC3Chain'
            SourceName           = 'SubCA'
            DestinationName      = 'VMware 6.x'
            AccessRules          = $accessRules
            Principal            = 'AuthenticatedUsers'
            AlsoPublishTemplate  = 'User'
            StatePath            = $StatePath
        }
        if ($PSBoundParameters.ContainsKey('CAName')) { $pipelineParams['CAName'] = $CAName }
        if ($PSBoundParameters.ContainsKey('Server')) { $pipelineParams['Server'] = $Server }
        if ($Force.IsPresent) { $pipelineParams['Force'] = $true }

        Invoke-AGTemplateScenario @pipelineParams
    }
}
