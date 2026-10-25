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

    .PARAMETER SkipLowPrivUser
        Leaves the low privileged lab user and its PAW RDP access in place.

    .PARAMETER LowPrivUserName
        The low privileged lab user to remove. Defaults to 'user'. It is deleted
        only when its description carries the ADCSGoat marker.

    .PARAMETER PawComputerName
        The workstation whose Remote Desktop Users group the lab user is removed
        from. Defaults to 'ADCSGoat-PAW'.

    .EXAMPLE
        Uninstall-ADCSGoat

        Removes the lab user, then tears down the deployment recorded in the
        default state file.
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
        [string]$Server,

        [Parameter()]
        [switch]$SkipLowPrivUser,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LowPrivUserName = 'user',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PawComputerName = 'ADCSGoat-PAW'
    )

    begin {
        if ([string]::IsNullOrEmpty($StatePath)) {
            $StatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ADCSGoat.State.xml'
        }
        $teardownParams = @{ StatePath = $StatePath }
        if ($PSBoundParameters.ContainsKey('Server')) { $teardownParams['Server'] = $Server }
    }

    process {
        if (-not $SkipLowPrivUser) {
            $userParams = @{}
            if ($PSBoundParameters.ContainsKey('Server')) { $userParams['Server'] = $Server }

            $serverPrefix = if ($Server) { "LDAP://$Server/" } else { 'LDAP://' }
            $rootDSE = New-Object System.DirectoryServices.DirectoryEntry("${serverPrefix}RootDSE")
            $netbiosName = Get-ADDomainNameFromNc -ConfigurationNC "$($rootDSE.configurationNamingContext)" @userParams

            # Group membership first: deleting the user first would leave an orphaned SID in the PAW group.
            try {
                Set-AGRdpUserAccess -ComputerName $PawComputerName -Member "$netbiosName\$LowPrivUserName" -Ensure Absent
            } catch {
                Write-Warning "Could not remove $netbiosName\$LowPrivUserName from Remote Desktop Users on ${PawComputerName}: $($_.Exception.Message)"
            }
            $null = Remove-AGLowPrivUser -UserName $LowPrivUserName @userParams
        }

        Invoke-AGDeployTeardown @teardownParams
    }
}
