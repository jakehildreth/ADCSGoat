function Test-AGDeployPreflight {
    <#
    .SYNOPSIS
        Runs the ADCSGoat preflight report before any AD write.

    .DESCRIPTION
        Implements the preflight report settled in ADCSGoat issue #24. Every
        check is read-only; nothing is ever changed to satisfy a check.

        Hard prerequisites (abort with a prerequisite error naming the check
        and remediation, before any AD write):

        - SelectedCAResolves        The selected CA resolves to exactly one
                                    pKIEnrollmentService object.
        - WebServerNameFlag         The Web Server source's
                                    msPKI-Certificate-Name-Flag carries bit
                                    0x1 (CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT).
        - DomainUsersCanEnrollUser  Domain Users can enroll through the
                                    built-in User template.

    .PARAMETER SelectedCA
        The pscustomobject returned by Get-AGEnrollmentService.

    .PARAMETER Server
        The domain controller to query. Defaults to the logon server.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with HardChecks and
        SoftObservations lists. Terminates on the first failed hard check.

    .EXAMPLE
        $ca = Get-AGEnrollmentService
        $report = Test-AGDeployPreflight -SelectedCA $ca
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [pscustomobject]$SelectedCA,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    begin {
        Add-Type -AssemblyName System.DirectoryServices

        if ([string]::IsNullOrEmpty($Server)) {
            $Server = [System.Net.Dns]::GetHostEntry($env:LOGONSERVER.TrimStart('\')).HostName
        }

        $rootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/RootDSE")
        $configurationPartition = "$($rootDSE.configurationNamingContext)"
        $defaultNamingContext = "$($rootDSE.defaultNamingContext)"
        $templatesDN = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$configurationPartition"

        $hardChecks = [System.Collections.Generic.List[object]]::new()
        $softObservations = [System.Collections.Generic.List[object]]::new()
    }

    process {
        #region Hard check 1: selected CA resolves to exactly one Enrollment Services object
        $caPath = "LDAP://$Server/$($SelectedCA.DistinguishedName)"
        $caCount = 0
        $caEntry = $null
        if ([System.DirectoryServices.DirectoryEntry]::Exists($caPath)) {
            $caEntry = New-Object System.DirectoryServices.DirectoryEntry($caPath)
            if ("$($caEntry.SchemaClassName)" -eq 'pKIEnrollmentService') { $caCount = 1 }
        }
        Resolve-AGPreflightHardCheck -Check 'SelectedCAResolves' -Value $caCount
        $hardChecks.Add([pscustomobject]@{ Check = 'SelectedCAResolves'; Passed = $true; Detail = $SelectedCA.DistinguishedName })
        #endregion

        #region Hard check 2: Web Server msPKI-Certificate-Name-Flag bit 0x1
        $webServerPath = "LDAP://$Server/CN=WebServer,$templatesDN"
        if (-not [System.DirectoryServices.DirectoryEntry]::Exists($webServerPath)) {
            $exception = New-Object System.InvalidOperationException("Web Server source template not found at 'CN=WebServer,$templatesDN'. AD CS built-in templates must be present. No AD changes were made.")
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'PrerequisiteFailed:WebServerNameFlag', [System.Management.Automation.ErrorCategory]::ObjectNotFound, 'WebServer')
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        $webServer = New-Object System.DirectoryServices.DirectoryEntry($webServerPath)
        $nameFlag = 0
        if ($webServer.Properties['msPKI-Certificate-Name-Flag'].Count -gt 0) {
            $nameFlag = [int]$webServer.Properties['msPKI-Certificate-Name-Flag'].Value
        }
        $webServer.Dispose()
        Resolve-AGPreflightHardCheck -Check 'WebServerNameFlag' -Value $nameFlag
        $hardChecks.Add([pscustomobject]@{ Check = 'WebServerNameFlag'; Passed = $true; Detail = "msPKI-Certificate-Name-Flag = 0x$($nameFlag.ToString('X'))" })
        #endregion

        #region Hard check 3: Domain Users can enroll through the built-in User template
        $userPath = "LDAP://$Server/CN=User,$templatesDN"
        if (-not [System.DirectoryServices.DirectoryEntry]::Exists($userPath)) {
            $exception = New-Object System.InvalidOperationException("Built-in User template not found at 'CN=User,$templatesDN'. AD CS built-in templates must be present. No AD changes were made.")
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'PrerequisiteFailed:DomainUsersCanEnrollUser', [System.Management.Automation.ErrorCategory]::ObjectNotFound, 'User')
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # Resolve Domain Users SID from the domain naming context.
        $domainNC = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/$defaultNamingContext")
        $domainSidBytes = $domainNC.Properties['objectSid'].Value
        $domainSid = New-Object System.Security.Principal.SecurityIdentifier($domainSidBytes, 0)
        $domainUsersSid = New-Object System.Security.Principal.SecurityIdentifier("$($domainSid.Value)-513")
        $domainNC.Dispose()

        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($userPath)
        $searcher.SearchScope = 'Base'
        $searcher.Filter = '(objectClass=*)'
        $searcher.PropertiesToLoad.Add('nTSecurityDescriptor') | Out-Null
        $searcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
        $result = $searcher.FindOne()
        $sdBytes = $result.Properties['ntsecuritydescriptor'][0]
        $rawSd = New-Object System.Security.AccessControl.RawSecurityDescriptor($sdBytes, 0)

        $canEnroll = Test-AGDomainUsersEnrollAllowed -Dacl $rawSd.DiscretionaryAcl -DomainUsersSid $domainUsersSid.Value
        Resolve-AGPreflightHardCheck -Check 'DomainUsersCanEnrollUser' -Value $canEnroll
        $hardChecks.Add([pscustomobject]@{ Check = 'DomainUsersCanEnrollUser'; Passed = $true; Detail = "Domain Users ($($domainUsersSid.Value)) holds Enroll on User" })
        #endregion

        # No soft observations are currently collected; the list stays on the
        # output so the report shape is stable for future additions.

        Write-Output ([pscustomobject]@{
            SelectedCA       = $SelectedCA
            HardChecks       = $hardChecks.ToArray()
            SoftObservations = $softObservations.ToArray()
        })
    }
}

function Resolve-AGPreflightHardCheck {
    <#
    .SYNOPSIS
        Enforces one preflight hard prerequisite. Internal seam: pure
        evaluation, unit-tested without touching a forest. A failed check
        aborts with a prerequisite error naming the check and remediation.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('SelectedCAResolves', 'WebServerNameFlag', 'DomainUsersCanEnrollUser')]
        [string]$Check,

        [Parameter()]
        [AllowNull()]
        $Value
    )

    process {
        switch ($Check) {
            'SelectedCAResolves' {
                if ([int]$Value -ne 1) {
                    $exception = New-Object System.InvalidOperationException("Prerequisite failed: the selected CA must resolve to exactly one pKIEnrollmentService object under CN=Enrollment Services (resolved $Value). Verify -CAName matches an installed enterprise CA. No AD changes were made.")
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'PrerequisiteFailed:SelectedCAResolves', [System.Management.Automation.ErrorCategory]::InvalidOperation, $Check)
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            }
            'WebServerNameFlag' {
                $flag = 0
                if ($null -ne $Value) { $flag = [int]$Value }
                if (($flag -band 0x1) -ne 0x1) {
                    $exception = New-Object System.InvalidOperationException("Prerequisite failed: the Web Server source template's msPKI-Certificate-Name-Flag (0x$($flag.ToString('X'))) lacks bit 0x1 (CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT), which ESC1 depends on. Remediation: restore the Web Server template's default 'Supply in the request' subject setting. ADCSGoat never changes a source template to satisfy a check. No AD changes were made.")
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'PrerequisiteFailed:WebServerNameFlag', [System.Management.Automation.ErrorCategory]::InvalidOperation, $Check)
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            }
            'DomainUsersCanEnrollUser' {
                if ($Value -ne $true) {
                    $exception = New-Object System.InvalidOperationException("Prerequisite failed: Domain Users cannot enroll through the built-in User template, which the VMware 6.x enroll-on-behalf-of chain requires. Remediation: restore the User template's default DACL granting Domain Users the Enroll extended right. ADCSGoat never changes the User ACL to satisfy a check. No AD changes were made.")
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'PrerequisiteFailed:DomainUsersCanEnrollUser', [System.Management.Automation.ErrorCategory]::InvalidOperation, $Check)
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            }
        }
    }
}

function Test-AGDomainUsersEnrollAllowed {
    <#
    .SYNOPSIS
        Returns $true when the supplied DACL grants the Domain Users SID the
        certificate Enroll extended right ({0e10c968-78fb-11d2-90d4-00c04f79dc55}).
        Internal seam: pure descriptor evaluation, unit-testable.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Security.AccessControl.GenericAcl]$Dacl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainUsersSid
    )

    process {
        $enrollGuid = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'
        foreach ($ace in $Dacl) {
            if ($ace.SecurityIdentifier.Value -ne $DomainUsersSid) { continue }
            if ($ace.AceType -ne [System.Security.AccessControl.AceType]::AccessAllowedObject) { continue }
            if ($ace -isnot [System.Security.AccessControl.ObjectAce]) { continue }
            if ($ace.ObjectAceType -ne $enrollGuid) { continue }
            # Extended right: mask 0x100 (ADS_RIGHT_DS_CONTROL_ACCESS).
            if (($ace.AccessMask -band 0x100) -eq 0x100) { return $true }
        }
        return $false
    }
}
