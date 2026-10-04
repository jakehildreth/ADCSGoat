function Save-AGDeployState {
    <#
    .SYNOPSIS
        Persists the deploy state file to disk.

    .DESCRIPTION
        Writes the in-memory state object (see New-AGDeployState) to disk as
        CLIXML so it is machine-readable and survives sessions and machines.
        This is the teardown source of truth. It is written before any AD
        change, and re-written as scenarios append clone records.

        The pre-change security descriptor binary form is serialized as a
        Base64 string inside the CLIXML so the byte array round-trips without
        loss.

    .PARAMETER State
        The state object produced by New-AGDeployState.

    .PARAMETER Path
        The destination file path. The module's deploy entrypoint passes a
        path next to the module root.

    .OUTPUTS
        None.

    .EXAMPLE
        Save-AGDeployState -State $state -Path "$PSScriptRoot/../ADCSGoat.State.xml"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [pscustomobject]$State,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    process {
        # Flatten the byte array to Base64 for lossless CLIXML round-trip.
        $persisted = [pscustomobject]@{
            SelectedCA                        = $State.SelectedCA
            CapturedAt                        = $State.CapturedAt
            PreChangeCertificateTemplates     = @($State.PreChangeCertificateTemplates | ForEach-Object { "$_" })
            PreChangeSecurityDescriptorSddl   = $State.PreChangeSecurityDescriptorSddl
            PreChangeSecurityDescriptorBinaryBase64 = [Convert]::ToBase64String([byte[]]$State.PreChangeSecurityDescriptorBinary)
            Clones                            = @($State.Clones)
        }

        $directory = Split-Path -Path $Path -Parent
        if ($directory -and -not (Test-Path -Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        $persisted | Export-Clixml -Path $Path -Force
        Write-Verbose "Deploy state written to '$Path'."
    }
}
