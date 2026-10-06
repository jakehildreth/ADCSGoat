function Uninstall-ADCSGoat {
    <#
    .SYNOPSIS
        Removes an ADCSGoat deployment, restoring pre-change state ACL-last.

    .DESCRIPTION
        Drives the teardown contract settled in ADCSGoat issue #30 from the
        state file written at deploy time. Restores, in order: clone cns are
        removed from the selected CA's certificateTemplates (and the attribute
        returned to its pre-change member set), clone template objects and
        their companion OID objects are deleted, and finally the Enrollment
        Services security descriptor is restored byte-for-byte — reversing the
        ESC5 CA-object grant last. Any failure before the ACL step aborts and
        leaves the grant in place, reporting what remains.

        Performs no legacy detection; it restores only what the state file
        records.

    .PARAMETER StatePath
        Where the deploy state file lives. Defaults to ADCSGoat.State.xml next
        to the module root.

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .EXAMPLE
        Uninstall-ADCSGoat

        Tears down the deployment recorded in the default state file.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'State-driven restore; destructive steps ordered ACL-last so a failure never strands a partial access state.')]
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$StatePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    begin {
        if ([string]::IsNullOrEmpty($StatePath)) {
            $StatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ADCSGoat.State.xml'
        }
        $teardownParams = @{ StatePath = $StatePath }
        if ($PSBoundParameters.ContainsKey('Server')) { $teardownParams['Server'] = $Server }
    }

    process {
        Invoke-AGDeployTeardown @teardownParams
    }
}
