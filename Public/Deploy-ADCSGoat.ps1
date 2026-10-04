function Deploy-ADCSGoat {
    <#
    .SYNOPSIS
        Runs the ADCSGoat deploy spine: select the CA, run the preflight
        report, and write the state file before any AD write.

    .DESCRIPTION
        Implements the deploy spine settled in ADCSGoat issue #26. The four
        scenario deploys plug into this spine; on its own it performs zero AD
        writes and is safe to run in any forest.

        Ordering contract (every failure aborts before any AD write):

        1. CA selection      Resolve the one issuing CA via -CAName, or
                             autodetect when the forest has exactly one
                             enterprise CA. Multi-CA without -CAName and an
                             invalid name both fail here.
        2. Preflight report  Hard prerequisites abort with a prerequisite
                             error naming the check + remediation; soft
                             observations warn and continue. Nothing is ever
                             changed to satisfy a check.
        3. State capture     The selected CA's certificateTemplates list and
                             nTSecurityDescriptor are captured for byte-for-
                             byte restoration at teardown.
        4. State file        Written to disk before any AD change. Scenario
                             deploys append per-clone records as they run.

    .PARAMETER CAName
        The cn of the enterprise CA's pKIEnrollmentService object. Optional;
        autodetected when the forest has exactly one enterprise CA.

    .PARAMETER StatePath
        Where the state file is written. Defaults to ADCSGoat.State.xml next
        to the module root.

    .PARAMETER SelectedCA
        Internal seam: a pre-resolved CA object (Name + DistinguishedName).
        When supplied, CA selection is skipped. Exists so orchestration tests
        can inject a broken CA without mutating AD.

    .PARAMETER Server
        The domain controller to contact. Defaults to the logon server.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with SelectedCA,
        PreflightReport, State, and StatePath.

    .EXAMPLE
        Deploy-ADCSGoat

        Autodetects the single CA, runs preflight, writes the state file.

    .EXAMPLE
        Deploy-ADCSGoat -CAName 'LabRootCA1'

        Selects the named CA explicitly.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CAName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$StatePath,

        [Parameter()]
        [ValidateNotNull()]
        [pscustomobject]$SelectedCA,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    begin {
        if ([string]::IsNullOrEmpty($StatePath)) {
            $StatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ADCSGoat.State.xml'
        }
    }

    process {
        # Forward -Server to the helpers only when the caller supplied it;
        # the helpers default to the logon server themselves and reject an
        # explicit null/empty value.
        $helperParams = @{}
        if ($PSBoundParameters.ContainsKey('Server')) { $helperParams['Server'] = $Server }

        # 1. CA selection. Fails (CANotFound / MultipleCAsFound /
        #    NoEnterpriseCAFound) before anything else happens.
        if ($null -eq $SelectedCA) {
            if ($PSBoundParameters.ContainsKey('CAName')) {
                $SelectedCA = Get-AGEnrollmentService -CAName $CAName @helperParams
            } else {
                $SelectedCA = Get-AGEnrollmentService @helperParams
            }
        }
        Write-Verbose "Deploying ADCSGoat to '$($SelectedCA.FullName)'."

        # 2. Preflight report. A failed hard prerequisite aborts here; soft
        #    observations warn and continue. No AD writes yet.
        $preflightReport = Test-AGDeployPreflight -SelectedCA $SelectedCA @helperParams

        # 3. State capture. Reads only.
        $state = New-AGDeployState -SelectedCA $SelectedCA @helperParams

        # 4. State file, written before any AD change.
        Save-AGDeployState -State $state -Path $StatePath
        Write-Verbose "State file written to '$StatePath' before any AD change."

        Write-Output ([pscustomobject]@{
            SelectedCA      = $SelectedCA
            PreflightReport = $preflightReport
            State           = $state
            StatePath       = $StatePath
        })
    }
}
