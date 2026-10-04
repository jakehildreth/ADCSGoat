function Invoke-AGTemplateScenario {
    <#
    .SYNOPSIS
        Runs the shared scenario deploy pipeline for one template scenario.

    .DESCRIPTION
        The pipeline every scenario deploy (issues #27-#30) shares:

          clone -> recipe -> rights -> publish -> record state

        1. Clone. The source template is cloned via Copy-AGTemplate (issue
           #25 kernel), which applies the fresh OID, schema upgrade, whole-
           descriptor copy, ownership marker, and collision contract.
        2. Recipe. The caller's -Recipe scriptblock runs against the resolved
           clone DirectoryEntry and commits any attribute overrides. ESC4
           passes no recipe (zero overrides).
        3. Rights. The caller's -AccessRules scriptblock returns the
           ActiveDirectoryAccessRule objects to layer on the copied source
           DACL.
        4. Publish. The clone's cn is added to the selected CA's
           certificateTemplates.
        5. State. The clone's actual cn, minted OID, companion OID object DN,
           and post-setup SDDL are appended to the deploy state file (#26).

        The source template is never written.

    .PARAMETER Scenario
        The scenario label recorded in the state file (e.g. 'ESC1').

    .PARAMETER SourceName
        The cn of the built-in source template (e.g. 'WebServer').

    .PARAMETER DestinationName
        The desired cn/displayName of the clone.

    .PARAMETER Recipe
        A scriptblock invoked as `& $Recipe $clone` that applies attribute
        overrides to the clone DirectoryEntry and commits them. Omit for
        scenarios with no attribute overrides.

    .PARAMETER AccessRules
        A scriptblock invoked as `& $AccessRules $domainUsersSid` that
        returns the ActiveDirectoryAccessRule objects to grant on the clone.
        Omit for scenarios that grant no template rights.

    .PARAMETER CAName
        The cn of the enterprise CA to publish to. Optional; autodetected
        when the forest has exactly one enterprise CA.

    .PARAMETER StatePath
        Where the deploy state file lives.

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .PARAMETER Force
        Replaces an ADCSGoat-owned existing clone without prompting.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with CloneCn, Oid, and
        CompanionOidObjectDN.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'AD writes gated by the Copy-AGTemplate collision prompt / -Force contract per module precedent.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Scenario,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationName,

        [Parameter()]
        [scriptblock]$Recipe,

        [Parameter()]
        [scriptblock]$AccessRules,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CAName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StatePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Add-Type -AssemblyName System.DirectoryServices

        # The prevailing repo idiom builds paths as "LDAP://$Server/DN", which
        # resolves correctly whether or not -Server was supplied.
        $serverPrefix = if ($PSBoundParameters.ContainsKey('Server')) { "LDAP://$Server/" } else { 'LDAP://' }

        $helperParams = @{}
        if ($PSBoundParameters.ContainsKey('Server')) { $helperParams['Server'] = $Server }
    }

    process {
        # Resolve the CA and load/create the state file.
        if ($PSBoundParameters.ContainsKey('CAName')) {
            $selectedCA = Get-AGEnrollmentService -CAName $CAName @helperParams
        } else {
            $selectedCA = Get-AGEnrollmentService @helperParams
        }

        if (Test-Path -Path $StatePath) {
            $state = Read-AGDeployState -Path $StatePath
        } else {
            $state = New-AGDeployState -SelectedCA $selectedCA @helperParams
        }

        # 1. Clone the source.
        $copyParams = @{ SourceName = $SourceName; DestinationName = $DestinationName }
        if ($Force.IsPresent) { $copyParams['Force'] = $true }
        if ($helperParams.ContainsKey('Server')) { $copyParams['Server'] = $helperParams['Server'] }
        $cloneResult = Copy-AGTemplate @copyParams
        $cloneCn = $cloneResult.DestinationName

        # Resolve the freshly created clone object.
        $rootDSE = New-Object System.DirectoryServices.DirectoryEntry("${serverPrefix}RootDSE")
        $configurationPartition = $rootDSE.configurationNamingContext
        $cloneDN = "CN=$cloneCn,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configurationPartition"
        $clone = New-Object System.DirectoryServices.DirectoryEntry("$serverPrefix$cloneDN")
        $clone.RefreshCache()

        # 2. Recipe: apply the caller's attribute overrides, if any.
        if ($PSBoundParameters.ContainsKey('Recipe') -and $null -ne $Recipe) {
            & $Recipe $clone
        }

        # 3. Rights: layer the caller's ACEs on the copied DACL, if any.
        if ($PSBoundParameters.ContainsKey('AccessRules') -and $null -ne $AccessRules) {
            $domainSid = (New-Object System.Security.Principal.NTAccount((Get-ADDomainNameFromNc -ConfigurationNC $configurationPartition @helperParams), 'Domain Users')).Translate([System.Security.Principal.SecurityIdentifier])
            $sd = $clone.ObjectSecurity
            foreach ($rule in @(& $AccessRules $domainSid)) {
                $sd.AddAccessRule($rule)
            }
            $clone.ObjectSecurity = $sd
            $clone.CommitChanges()
        }

        $postSetupSddl = $clone.ObjectSecurity.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::All)
        $clone.Dispose()

        # 4. Publish on the selected CA.
        $caEntry = New-Object System.DirectoryServices.DirectoryEntry("$serverPrefix$($selectedCA.DistinguishedName)")
        $published = @($caEntry.Properties['certificateTemplates'] | ForEach-Object { "$_" })
        if ($published -notcontains $cloneCn) {
            $caEntry.PutEx(3, 'certificateTemplates', @($cloneCn))   # ADS_PROPERTY_APPEND
            $caEntry.SetInfo()
        }
        $caEntry.Dispose()

        # 5. Record the clone in the state file.
        Add-AGDeployStateClone -State $state -Clone ([pscustomobject]@{
            Scenario             = $Scenario
            Cn                   = $cloneCn
            Oid                  = $cloneResult.Oid
            CompanionOidObjectDN = $cloneResult.CompanionOidObjectDN
            PostSetupSddl        = $postSetupSddl
        })
        Save-AGDeployState -State $state -Path $StatePath

        Write-Output ([pscustomobject]@{
            CloneCn              = $cloneCn
            Oid                  = $cloneResult.Oid
            CompanionOidObjectDN = $cloneResult.CompanionOidObjectDN
        })
    }
}
