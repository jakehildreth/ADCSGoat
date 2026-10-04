function Read-AGDeployState {
    <#
    .SYNOPSIS
        Reads the deploy state file from disk.

    .DESCRIPTION
        Loads a state file written by Save-AGDeployState and rehydrates the
        binary security descriptor from its Base64 serialization. Returns the
        state object in the same in-memory shape New-AGDeployState produced.

    .PARAMETER Path
        The state file path.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. The rehydrated state
        object, or a terminating error if the file does not exist.

    .EXAMPLE
        $state = Read-AGDeployState -Path "$PSScriptRoot/../ADCSGoat.State.xml"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    process {
        if (-not (Test-Path -Path $Path)) {
            $exception = New-Object System.IO.FileNotFoundException("Deploy state file not found at '$Path'.", $Path)
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'DeployStateFileNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $Path)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        $persisted = Import-Clixml -Path $Path

        Write-Output ([pscustomobject]@{
            SelectedCA                        = $persisted.SelectedCA
            CapturedAt                        = $persisted.CapturedAt
            PreChangeCertificateTemplates     = @($persisted.PreChangeCertificateTemplates | ForEach-Object { "$_" })
            PreChangeSecurityDescriptorSddl   = $persisted.PreChangeSecurityDescriptorSddl
            PreChangeSecurityDescriptorBinary = [Convert]::FromBase64String($persisted.PreChangeSecurityDescriptorBinaryBase64)
            Clones                            = @($persisted.Clones)
        })
    }
}

function Add-AGDeployStateClone {
    <#
    .SYNOPSIS
        Appends a scenario clone record to the deploy state object.

    .DESCRIPTION
        Scenario deploys record each clone's actual identity here after
        creation: the actual cn used (including the deterministic fallback
        name on unowned collision), the minted OID, the companion
        ms-PKI-Enterprise-Oid object DN, and the post-setup SDDL. The caller
        re-saves the state file afterward; teardown reads these records.

    .PARAMETER State
        The state object produced by New-AGDeployState.

    .PARAMETER Clone
        A pscustomobject with Scenario, Cn, Oid, CompanionOidObjectDN, and
        PostSetupSddl.

    .OUTPUTS
        None. The state object's Clones list is updated in place.

    .EXAMPLE
        Add-AGDeployStateClone -State $state -Clone $cloneRecord
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [pscustomobject]$State,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [pscustomobject]$Clone
    )

    process {
        $State.Clones = @($State.Clones) + $Clone
    }
}
