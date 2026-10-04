function Deploy-AGEsc1 {
    <#
    .SYNOPSIS
        Deploys the ESC1 scenario: "Copy of Web Server" with Client
        Authentication added by mistake.

    .DESCRIPTION
        Implements the ESC1 recipe settled in ADCSGoat issue #22 and the
        scenario pipeline from issue #27. The pipeline is:

          recipe -> clone -> scenario rights -> publish -> record state

        1. Clone. The built-in Web Server template is cloned via
           Copy-AGTemplate (issue #25 kernel): fresh OID, GUI-authentic
           v1->v2 schema upgrade, whole source security descriptor copied,
           ownership marker set, collision contract applied.
        2. Recipe. Client Authentication (1.3.6.1.5.5.7.3.2) is APPENDED to
           both pKIExtendedKeyUsage and msPKI-Certificate-Application-Policy.
           Existing EKUs are preserved (the admin-added-a-mistake narrative).
           msPKI-Certificate-Application-Policy may be absent on a v1 source;
           it is created on the clone.
        3. Rights. Domain Users are granted Read + Enroll, layered on top of
           the copied source DACL (the source DACL stays intact underneath).
        4. Publish. The clone's cn is added to the selected CA's
           certificateTemplates.
        5. State. The clone's actual cn, minted OID, and companion OID object
           DN are appended to the deploy state file (issue #26).

        The Web Server source is never written; verification asserts it is
        byte-identical before and after.

    .PARAMETER CAName
        The cn of the enterprise CA to publish to. Optional; autodetected
        when the forest has exactly one enterprise CA.

    .PARAMETER StatePath
        Where the deploy state file lives. Defaults to ADCSGoat.State.xml
        next to the module root.

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .PARAMETER Force
        Replaces an ADCSGoat-owned existing clone without prompting. Required
        for non-interactive redeploy.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with CloneCn, Oid, and
        CompanionOidObjectDN.

    .EXAMPLE
        Deploy-AGEsc1

        Clones Web Server, adds Client Auth, grants Domain Users enroll, and
        publishes on the forest's single CA.

    .EXAMPLE
        Deploy-AGEsc1 -CAName 'LabRootCA1' -Force

        Redeploys against the named CA, replacing any owned clone.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'AD writes gated by the Copy-AGTemplate collision prompt / -Force contract per module precedent.')]
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CAName,

        [Parameter()]
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

        if ([string]::IsNullOrEmpty($StatePath)) {
            $StatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ADCSGoat.State.xml'
        }

        $clientAuthOid = '1.3.6.1.5.5.7.3.2'
        $enrollGuid = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'
        $allPropsGuid = [guid]'00000000-0000-0000-0000-000000000000'

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

        # 1. Clone the Web Server source.
        $copyParams = @{ SourceName = 'WebServer'; DestinationName = 'Copy of Web Server' }
        if ($Force.IsPresent) { $copyParams['Force'] = $true }
        if ($PSBoundParameters.ContainsKey('Server')) { $copyParams['Server'] = $Server }
        $cloneResult = Copy-AGTemplate @copyParams
        $cloneCn = $cloneResult.DestinationName

        # Resolve the freshly created clone object.
        $rootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($helperParams['Server'])/RootDSE".Replace('LDAP:///','LDAP://'))
        $configurationPartition = $rootDSE.configurationNamingContext
        $cloneDN = "CN=$cloneCn,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configurationPartition"
        $clone = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($helperParams['Server'])/$cloneDN".Replace('LDAP:///','LDAP://'))
        $clone.RefreshCache()

        # 2. Recipe: append Client Auth to both EKU attributes, preserving the
        #    existing Server Auth value. The v2-only application-policy
        #    attribute may be absent on a v1-sourced clone; create it.
        $existingEku = @($clone.Properties['pKIExtendedKeyUsage'] | ForEach-Object { "$_" })
        if ($existingEku -notcontains $clientAuthOid) {
            $clone.Properties['pKIExtendedKeyUsage'].Add($clientAuthOid) | Out-Null
        }

        $existingAp = @($clone.Properties['msPKI-Certificate-Application-Policy'] | ForEach-Object { "$_" })
        if ($existingAp.Count -eq 0) {
            # Seed from pKIExtendedKeyUsage so the two stay in sync, then add
            # Client Auth (the seed already carries it via the line above).
            foreach ($v in $existingEku) { $clone.Properties['msPKI-Certificate-Application-Policy'].Add($v) | Out-Null }
            if ($existingEku -notcontains $clientAuthOid) { $clone.Properties['msPKI-Certificate-Application-Policy'].Add($clientAuthOid) | Out-Null }
        } elseif ($existingAp -notcontains $clientAuthOid) {
            $clone.Properties['msPKI-Certificate-Application-Policy'].Add($clientAuthOid) | Out-Null
        }
        $clone.CommitChanges()

        # 3. Rights: Domain Users Read + Enroll, layered on the copied DACL.
        $domainSid = (New-Object System.Security.Principal.NTAccount((Get-ADDomainNameFromNc -ConfigurationNC $configurationPartition @helperParams), 'Domain Users')).Translate([System.Security.Principal.SecurityIdentifier])
        $sd = $clone.ObjectSecurity
        $sd.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $domainSid, ([System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight), ([System.Security.AccessControl.AccessControlType]::Allow), $enrollGuid))
        $sd.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $domainSid, ([System.DirectoryServices.ActiveDirectoryRights]::GenericRead), ([System.Security.AccessControl.AccessControlType]::Allow), $allPropsGuid))
        $clone.ObjectSecurity = $sd
        $clone.CommitChanges()

        $postSetupSddl = $clone.ObjectSecurity.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::All)
        $clone.Dispose()

        # 4. Publish on the selected CA.
        $caEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($helperParams['Server'])/$($selectedCA.DistinguishedName)".Replace('LDAP:///','LDAP://'))
        $published = @($caEntry.Properties['certificateTemplates'] | ForEach-Object { "$_" })
        if ($published -notcontains $cloneCn) {
            $caEntry.PutEx(3, 'certificateTemplates', @($cloneCn))   # ADS_PROPERTY_APPEND
            $caEntry.SetInfo()
        }
        $caEntry.Dispose()

        # 5. Record the clone in the state file.
        Add-AGDeployStateClone -State $state -Clone ([pscustomobject]@{
            Scenario             = 'ESC1'
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

function Get-ADDomainNameFromNc {
    <#
    .SYNOPSIS
        Derives the NetBIOS domain name from the configuration naming context.
        Internal helper: 'CN=Configuration,DC=adcs,DC=goat' -> 'ADCS'. Used to
        build the 'DOMAIN\Domain Users' NTAccount for SID resolution.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ConfigurationNC,

        [Parameter()]
        [string]$Server
    )

    process {
        $rootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/RootDSE".Replace('LDAP:///','LDAP://'))
        $defaultNC = "$($rootDSE.defaultNamingContext)"
        # NetBIOS name lives on the domain's crossRef object in the Partitions
        # container, keyed by nCName = the domain DN.
        $partitionsDN = "CN=Partitions,$ConfigurationNC"
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/$partitionsDN".Replace('LDAP:///','LDAP://'))
        $searcher.Filter = "(&(objectClass=crossRef)(nCName=$defaultNC))"
        $searcher.PropertiesToLoad.Add('nETBIOSName') | Out-Null
        $result = $searcher.FindOne()
        if ($null -eq $result) {
            throw "Could not resolve domain NetBIOS name for '$defaultNC'."
        }
        "$($result.Properties['netbiosname'][0])"
    }
}
