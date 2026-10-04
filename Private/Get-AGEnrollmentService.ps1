function Get-AGEnrollmentService {
    <#
    .SYNOPSIS
        Resolves the single selected enterprise CA for the ADCSGoat deploy spine.

    .DESCRIPTION
        Implements the selected-CA contract settled in ADCSGoat issue #24.

        - When -CAName is supplied, the CA with that exact name under
          CN=Enrollment Services,CN=Public Key Services,CN=Services,<ConfigNC>
          is resolved. An unknown name fails with error id 'CANotFound'
          listing the CAs that do exist.
        - When -CAName is omitted and the forest holds exactly one enterprise
          CA, that CA is autodetected.
        - When -CAName is omitted and the forest holds multiple enterprise
          CAs, the function fails with error id 'MultipleCAsFound' listing
          every CA and demanding -CAName. Zero CAs fails with
          'NoEnterpriseCAFound'.

        Every failure happens before any AD write. The CA's identity is its
        pKIEnrollmentService object, the object whose certificateTemplates
        attribute lists the templates the CA issues. The returned object
        identifies the CA as '<host FQDN>\<CA name>' via FullName, plus its
        Name, HostFqdn, and DistinguishedName.

    .PARAMETER CAName
        The cn of the enterprise CA's pKIEnrollmentService object
        (e.g. 'LabRootCA1'). Optional; autodetected when the forest has
        exactly one enterprise CA.

    .PARAMETER Server
        The domain controller to query. Defaults to the logon server.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with Name, HostFqdn,
        FullName ('<host FQDN>\<CA name>'), and DistinguishedName of the
        selected CA's pKIEnrollmentService object.

    .EXAMPLE
        Get-AGEnrollmentService

        Autodetects the forest's single enterprise CA.

    .EXAMPLE
        Get-AGEnrollmentService -CAName 'LabRootCA1'

        Selects the named CA, failing if it does not exist.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CAName,

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
        $configurationPartition = $rootDSE.configurationNamingContext
        $enrollmentServicesDN = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$configurationPartition"
    }

    process {
        $container = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/$enrollmentServicesDN")

        # Loop variables are deliberately not named $caName: PowerShell
        # variable names are case-insensitive, so $caName would silently
        # overwrite the $CAName parameter.
        $candidates = @(
            foreach ($child in $container.Children) {
                $childName = "$($child.Properties['cn'].Value)"
                $childHostFqdn = "$($child.Properties['dNSHostName'].Value)"
                [pscustomobject]@{
                    Name              = $childName
                    HostFqdn          = $childHostFqdn
                    FullName          = "$childHostFqdn\$childName"
                    DistinguishedName = "$($child.Properties['distinguishedName'].Value)"
                }
                $child.Dispose()
            }
        )
        $container.Dispose()

        if ($PSBoundParameters.ContainsKey('CAName')) {
            $match = @($candidates | Where-Object { $_.Name -eq $CAName })
            if ($match.Count -eq 0) {
                $available = ($candidates | ForEach-Object { $_.Name }) -join ', '
                $exception = New-Object System.InvalidOperationException("CA '$CAName' was not found under '$enrollmentServicesDN'. Available enterprise CAs: $available. No AD changes were made.")
                $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'CANotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $CAName)
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
            Write-Output $match[0]
            return
        }

        if ($candidates.Count -eq 0) {
            $exception = New-Object System.InvalidOperationException("No enterprise CA found under '$enrollmentServicesDN'. Is AD CS installed in this forest? No AD changes were made.")
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'NoEnterpriseCAFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $enrollmentServicesDN)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        if ($candidates.Count -gt 1) {
            $available = ($candidates | ForEach-Object { $_.Name }) -join ', '
            $exception = New-Object System.InvalidOperationException("Multiple enterprise CAs found: $available. Rerun with -CAName to select one. No AD changes were made.")
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'MultipleCAsFound', [System.Management.Automation.ErrorCategory]::InvalidOperation, $enrollmentServicesDN)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        Write-Output $candidates[0]
    }
}

function Resolve-AGEnrollmentServiceSelection {
    <#
    .SYNOPSIS
        Pure resolution of the selected-CA contract against a supplied
        candidate list. Internal seam; LDAP discovery lives in
        Get-AGEnrollmentService. Exists so the multi-CA, zero-CA, and
        invalid-name failures are unit-testable without touching a forest.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [pscustomobject[]]$Candidates,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CAName
    )

    process {
        if (-not [string]::IsNullOrEmpty($CAName)) {
            $match = @($Candidates | Where-Object { $_.Name -eq $CAName })
            if ($match.Count -eq 0) {
                $available = ($Candidates | ForEach-Object { $_.Name }) -join ', '
                $exception = New-Object System.InvalidOperationException("CA '$CAName' was not found. Available enterprise CAs: $available. No AD changes were made.")
                $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'CANotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $CAName)
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
            Write-Output $match[0]
            return
        }

        if ($Candidates.Count -eq 0) {
            $exception = New-Object System.InvalidOperationException('No enterprise CA found in the forest. No AD changes were made.')
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'NoEnterpriseCAFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $null)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        if ($Candidates.Count -gt 1) {
            $available = ($Candidates | ForEach-Object { $_.Name }) -join ', '
            $exception = New-Object System.InvalidOperationException("Multiple enterprise CAs found: $available. Rerun with -CAName to select one. No AD changes were made.")
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'MultipleCAsFound', [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        Write-Output $Candidates[0]
    }
}
