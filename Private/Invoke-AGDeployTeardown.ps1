function Invoke-AGDeployTeardown {
    <#
    .SYNOPSIS
        Tears down an ADCSGoat deployment from its state file, ACL-last.

    .DESCRIPTION
        Implements the teardown contract settled in ADCSGoat issue #30. Driven
        entirely by the state file written before any AD change; it performs no
        legacy detection and touches nothing outside the recorded state.

        Ordering is ACL-last so that a failure can never strand a
        half-restored access state:

        1. Remove every recorded clone cn from the selected CA's
           certificateTemplates (and restore the attribute to its pre-change
           member set).
        2. Delete each recorded clone template object and its companion
           ms-PKI-Enterprise-Oid object.
        3. Restore the Enrollment Services pre-change security descriptor
           byte-for-byte, LAST. Any failure in steps 1–2 aborts before this
           step, leaving the scenario grant in place and reporting what
           remains.

        On success the state file is removed; on a step 1–2 failure it is left
        on disk so teardown can be rerun.

    .PARAMETER StatePath
        Where the deploy state file lives. Defaults to ADCSGoat.State.xml next
        to the module root.

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .OUTPUTS
        None.

    .EXAMPLE
        Invoke-AGDeployTeardown

        Restores the forest to the recorded pre-change state, ACL last.
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
        Add-Type -AssemblyName System.DirectoryServices

        if ([string]::IsNullOrEmpty($StatePath)) {
            $StatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ADCSGoat.State.xml'
        }
        $helperParams = @{}
        if ($PSBoundParameters.ContainsKey('Server')) { $helperParams['Server'] = $Server }
        $serverPrefix = if ($PSBoundParameters.ContainsKey('Server')) { "LDAP://$Server/" } else { 'LDAP://' }
    }

    process {
        $state = Read-AGDeployState -Path $StatePath
        $caDN = $state.SelectedCA.DistinguishedName
        $caPath = "$serverPrefix$caDN"
        $clones = @($state.Clones)

        # Steps 1-2 are guarded together: any failure here aborts BEFORE the
        # ACL restore, so the scenario grant is never stripped while objects or
        # publication state remain that a rerun would still need to clean.
        try {
            # 1. certificateTemplates: remove recorded clone cns, then restore
            #    the exact pre-change member set (covers values an exercise
            #    added beyond the clones, e.g. a published Copy of Workstation).
            $caEntry = New-Object System.DirectoryServices.DirectoryEntry($caPath)
            $caEntry.RefreshCache()
            $current = @($caEntry.Properties['certificateTemplates'] | ForEach-Object { "$_" })

            $cloneCns = @($clones | ForEach-Object { "$($_.Cn)" })
            $toStrip = @($current | Where-Object { $cloneCns -contains $_ })
            foreach ($cn in $toStrip) {
                $caEntry.PutEx(4, 'certificateTemplates', @($cn))   # ADS_PROPERTY_DELETE
                Write-Verbose "Removed '$cn' from '$caDN' certificateTemplates."
            }

            # Restore the pre-change member set: remove anything now present
            # that was not there pre-change, and re-add any pre-change value
            # that is now missing.
            $caEntry.RefreshCache()
            $now = @($caEntry.Properties['certificateTemplates'] | ForEach-Object { "$_" })
            $pre = @($state.PreChangeCertificateTemplates)
            foreach ($extra in @($now | Where-Object { $pre -notcontains $_ })) {
                $caEntry.PutEx(4, 'certificateTemplates', @($extra))
                Write-Verbose "Restored certificateTemplates: removed unexpected value '$extra'."
            }
            foreach ($missing in @($pre | Where-Object { $now -notcontains $_ })) {
                $caEntry.PutEx(3, 'certificateTemplates', @($missing))   # ADS_PROPERTY_APPEND
                Write-Verbose "Restored certificateTemplates: re-added pre-change value '$missing'."
            }
            $caEntry.SetInfo()
            $caEntry.Dispose()

            # 2. Delete clone objects + companion OID objects.
            foreach ($clone in $clones) {
                Remove-AGTemplate -Name "$($clone.Cn)" @helperParams
            }
        } catch {
            $remaining = @()
            if (Test-Path -Path $StatePath) { $remaining += "state file '$StatePath'" }
            $exception = New-Object System.InvalidOperationException("Teardown aborted before the ACL restore: $($_.Exception.Message) The Enrollment Services security descriptor was left unchanged and the scenario grant remains in place. Remaining: $($remaining -join '; '). Rerun Invoke-AGDeployTeardown after resolving the cause.")
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'TeardownAbortedBeforeAclRestore', [System.Management.Automation.ErrorCategory]::NotSpecified, $caDN)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # 3. Restore the Enrollment Services security descriptor byte-for-byte,
        #    LAST. Reached only when steps 1-2 completed cleanly. The captured
        #    raw nTSecurityDescriptor bytes are written straight to the
        #    attribute; round-tripping through ActiveDirectorySecurity and
        #    ObjectSecurity drops inheritance control flags (e.g. OICI), so it
        #    is not a byte-exact restore.
        $restoreEntry = New-Object System.DirectoryServices.DirectoryEntry($caPath)
        $restoreEntry.RefreshCache(@('nTSecurityDescriptor'))
        $restoreEntry.Properties['nTSecurityDescriptor'].Value = [byte[]]$state.PreChangeSecurityDescriptorBinary
        $restoreEntry.CommitChanges()
        $restoreEntry.Dispose()
        Write-Verbose "Restored the Enrollment Services security descriptor byte-for-byte (last step)."

        Remove-Item -Path $StatePath -Force -ErrorAction SilentlyContinue
        Write-Verbose "Removed state file '$StatePath'."
    }
}
