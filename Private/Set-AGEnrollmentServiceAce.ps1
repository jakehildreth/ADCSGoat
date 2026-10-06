function Set-AGEnrollmentServiceAce {
    <#
    .SYNOPSIS
        Adds access rules to a CA's pKIEnrollmentService directory object.

    .DESCRIPTION
        The ESC5 half of the unpublished chain (issue #30): layers access rules
        onto the DACL of the pKIEnrollmentService object — the directory object
        that holds certificateTemplates — never the CA host or service security
        descriptor. The copied DACL is preserved; rules are added, not replaced.

        Add is idempotent: an identical rule (same trustee, rights, type, and
        object type) already present is skipped, so redeploy never stacks a
        duplicate ACE. Teardown does not surgically remove the grant — it
        byte-restores the CA's pre-change security descriptor captured in the
        state file (see New-AGDeployState), which reverses this wholesale.

    .PARAMETER DistinguishedName
        The distinguished name of the CA's pKIEnrollmentService object.

    .PARAMETER AccessRules
        The ActiveDirectoryAccessRule objects to add.

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .EXAMPLE
        $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $authUsersSid, 'GenericAll', 'Allow', ([guid]::Empty)
        Set-AGEnrollmentServiceAce -DistinguishedName $ca.DistinguishedName -AccessRules $rule
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'AD writes gated by the caller scenario deploy collision / -Force contract per module precedent.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistinguishedName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.DirectoryServices.ActiveDirectoryAccessRule[]]$AccessRules,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    begin {
        Add-Type -AssemblyName System.DirectoryServices
        $serverPrefix = if ($PSBoundParameters.ContainsKey('Server')) { "LDAP://$Server/" } else { 'LDAP://' }
    }

    process {
        $path = "$serverPrefix$DistinguishedName"
        if (-not [System.DirectoryServices.DirectoryEntry]::Exists($path)) {
            $exception = New-Object System.InvalidOperationException("Enrollment Services object not found at '$path'. No AD changes were made.")
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'EnrollmentServiceNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $DistinguishedName)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        $entry = New-Object System.DirectoryServices.DirectoryEntry($path)
        $sd = $entry.ObjectSecurity

        $added = 0
        foreach ($rule in $AccessRules) {
            # Dedupe predicate extracted pure (Test-AGAccessRulePresent) so it
            # is unit-testable without a forest.
            if (-not (Test-AGAccessRulePresent -ExistingRules $sd.Access -Rule $rule)) {
                $sd.AddAccessRule($rule)
                $added++
            }
        }

        if ($added -gt 0) {
            $entry.ObjectSecurity = $sd
            $entry.CommitChanges()
            Write-Verbose "Added $added access rule(s) to '$DistinguishedName'."
        } else {
            Write-Verbose "All access rules already present on '$DistinguishedName'; no change."
        }

        $entry.Dispose()
    }
}

function Test-AGAccessRulePresent {
    <#
    .SYNOPSIS
        Returns $true when an identical access rule already exists in a DACL.

    .DESCRIPTION
        Pure predicate matching trustee (SID), rights, access type, and object
        type. Internal seam for Set-AGEnrollmentServiceAce's idempotency,
        unit-testable without a forest.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        $ExistingRules,

        [Parameter(Mandatory)]
        [System.DirectoryServices.ActiveDirectoryAccessRule]$Rule
    )

    process {
        foreach ($existing in @($ExistingRules)) {
            if ($existing.IdentityReference.Value -eq $Rule.IdentityReference.Value -and
                $existing.ActiveDirectoryRights -eq $Rule.ActiveDirectoryRights -and
                $existing.AccessControlType -eq $Rule.AccessControlType -and
                "$($existing.ObjectType)" -eq "$($Rule.ObjectType)") {
                return $true
            }
        }
        return $false
    }
}
