function New-AGDeployState {
    <#
    .SYNOPSIS
        Captures the pre-change deploy state for the selected CA.

    .DESCRIPTION
        Implements the state-capture half of the ADCSGoat state-file contract
        settled in issue #24. Reads the selected CA's pKIEnrollmentService
        object and records, before any AD write:

        - the selected CA identity + DN;
        - the pre-change certificateTemplates value list (exact member set);
        - the pre-change nTSecurityDescriptor, both as SDDL and as the raw
          binary form so teardown can restore it byte-for-byte.

        The Clones list starts empty; scenario deploys append one record per
        clone via Add-AGDeployStateClone. This function performs reads only.

    .PARAMETER SelectedCA
        The pscustomobject returned by Get-AGEnrollmentService (Name +
        DistinguishedName of the pKIEnrollmentService object).

    .PARAMETER Server
        The domain controller to query. Defaults to the logon server.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. The in-memory state
        object, ready to persist with Save-AGDeployState.

    .EXAMPLE
        $ca = Get-AGEnrollmentService
        $state = New-AGDeployState -SelectedCA $ca
    #>
    # ShouldProcess is deliberately not implemented: this is a read-only
    # capture (LDAP reads of the Enrollment Services object). The 'New' verb
    # triggers the analyzer, but no system state is changed.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Read-only state capture; the New verb is a false positive.')]
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
    }

    process {
        $path = "LDAP://$Server/$($SelectedCA.DistinguishedName)"
        if (-not [System.DirectoryServices.DirectoryEntry]::Exists($path)) {
            $exception = New-Object System.InvalidOperationException("Selected CA object not found at '$path'. Cannot capture pre-change state.")
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'SelectedCAObjectNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $SelectedCA.DistinguishedName)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        $entry = New-Object System.DirectoryServices.DirectoryEntry($path)
        $entry.RefreshCache()

        $certificateTemplates = @($entry.Properties['certificateTemplates'] | ForEach-Object { "$_" })

        $sd = $entry.ObjectSecurity
        $sddl = $sd.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::All)
        $binary = $sd.GetSecurityDescriptorBinaryForm()
        $entry.Dispose()

        Write-Output ([pscustomobject]@{
            SelectedCA                       = $SelectedCA
            CapturedAt                       = (Get-Date).ToUniversalTime().ToString('o')
            PreChangeCertificateTemplates    = $certificateTemplates
            PreChangeSecurityDescriptorSddl  = $sddl
            PreChangeSecurityDescriptorBinary = $binary
            Clones                           = @()
        })
    }
}
