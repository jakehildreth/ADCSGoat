function Deploy-AGEsc5Chain {
    <#
    .SYNOPSIS
        Deploys the ESC4-on-unpublished-template + ESC5-on-CA-object chain.

    .DESCRIPTION
        Implements the unpublished chain settled in ADCSGoat issue #30, riding
        the shared scenario pipeline (Invoke-AGTemplateScenario, issue #27).

        The template half is ESC4: "Copy of Workstation" is a verbatim clone of
        the built-in Workstation Authentication template (schema v2) with zero
        attribute overrides and Domain Users Full Control (GenericAll) layered
        on the copied source DACL. It is deliberately NOT published on the
        selected CA — the attacker must first abuse the ESC5 grant to enable it.

        The CA half is ESC5: Authenticated Users are granted Full Control
        (GenericAll) on the selected CA's pKIEnrollmentService directory object
        — the object that holds certificateTemplates — never the CA host or
        service security descriptor. That grant lets a low-privileged principal
        edit certificateTemplates (publish Copy of Workstation, turning the
        ESC4 into an ESC1) and more.

        Redeploy enforces pristine state: if an exercise published Copy of
        Workstation, its cn is stripped from certificateTemplates and the
        removal is logged; the clone itself is replaced under the standard
        collision contract. The Workstation source is never written; the grant
        is reversed at teardown by byte-restoring the CA's pre-change security
        descriptor from the state file.

    .PARAMETER CAName
        The cn of the enterprise CA to target. Optional; autodetected when the
        forest has exactly one enterprise CA.

    .PARAMETER StatePath
        Where the deploy state file lives. Defaults to ADCSGoat.State.xml next
        to the module root.

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .PARAMETER Force
        Replaces an ADCSGoat-owned existing clone without prompting. Required
        for non-interactive redeploy.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with CloneCn, Oid, and
        CompanionOidObjectDN.

    .EXAMPLE
        Deploy-AGEsc5Chain

        Clones Workstation Authentication to 'Copy of Workstation' (unpublished,
        Domain Users Full Control) and grants Authenticated Users Full Control
        on the forest's single CA object.

    .EXAMPLE
        Deploy-AGEsc5Chain -CAName 'LabRootCA1' -Force

        Redeploys against the named CA, replacing any owned clone and
        re-enforcing the unpublished pristine state.
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
        Add-Type -AssemblyName System.DirectoryServices

        if ([string]::IsNullOrEmpty($StatePath)) {
            $StatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ADCSGoat.State.xml'
        }

        $allPropsGuid = [guid]'00000000-0000-0000-0000-000000000000'

        # Rights on the clone: Domain Users Full Control (GenericAll), layered
        # on the copied DACL. No recipe: zero attribute overrides.
        $accessRules = {
            param($domainSid)
            New-Object System.DirectoryServices.ActiveDirectoryAccessRule $domainSid, ([System.DirectoryServices.ActiveDirectoryRights]::GenericAll), ([System.Security.AccessControl.AccessControlType]::Allow), $allPropsGuid
        }

        $helperParams = @{}
        if ($PSBoundParameters.ContainsKey('Server')) { $helperParams['Server'] = $Server }
    }

    process {
        # 1. The unpublished ESC4 clone. SkipPublish keeps its cn out of the
        #    selected CA's certificateTemplates and strips it on redeploy.
        $pipelineParams = @{
            Scenario        = 'ESC5Chain'
            SourceName      = 'Workstation'
            DestinationName = 'Copy of Workstation'
            AccessRules     = $accessRules
            SkipPublish     = $true
            StatePath       = $StatePath
        }
        if ($PSBoundParameters.ContainsKey('CAName')) { $pipelineParams['CAName'] = $CAName }
        if ($helperParams.ContainsKey('Server')) { $pipelineParams['Server'] = $helperParams['Server'] }
        if ($Force.IsPresent) { $pipelineParams['Force'] = $true }

        $cloneResult = Invoke-AGTemplateScenario @pipelineParams

        # 2. The ESC5 grant: Authenticated Users Full Control on the selected
        #    CA's pKIEnrollmentService directory object (additive + idempotent).
        if ($PSBoundParameters.ContainsKey('CAName')) {
            $selectedCA = Get-AGEnrollmentService -CAName $CAName @helperParams
        } else {
            $selectedCA = Get-AGEnrollmentService @helperParams
        }
        $authenticatedUsersSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-11')
        $caGrant = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $authenticatedUsersSid, ([System.DirectoryServices.ActiveDirectoryRights]::GenericAll), ([System.Security.AccessControl.AccessControlType]::Allow), $allPropsGuid
        Set-AGEnrollmentServiceAce -DistinguishedName $selectedCA.DistinguishedName -AccessRules $caGrant @helperParams

        Write-Output $cloneResult
    }
}
