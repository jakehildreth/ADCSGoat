function Set-AGTemplateAce {

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$Server,    
        [Parameter(ValueFromPipeline, Mandatory)]
        [string[]]$TemplateName,
        [Parameter(Mandatory)]
        [ValidateSet('Enroll', 'FullControl', 'GenericAll', 'WriteProperty')]
        [string]$AceType
    )

    begin {

        Add-Type -AssemblyName System.DirectoryServices

        # ============================================================
        # Get Configuration Naming Context
        # ============================================================

        try {
            $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/RootDSE")
            $ConfigurationPartition = $RootDSE.configurationNamingContext
        }
        catch {
            throw "Failed to query RootDSE on $Server. $_"
        }

        $TemplateContainer = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigurationPartition"

        # ============================================================
        # Security Identifiers
        # ============================================================

        $AuthenticatedUsers = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-11')

        # ============================================================
        # AD Rights
        # ============================================================

        $ExtendedRight = [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
        $GenericAll = [System.DirectoryServices.ActiveDirectoryRights]::GenericAll
        $GenericRead = [System.DirectoryServices.ActiveDirectoryRights]::GenericRead
        $WriteProperty = [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty

        # ============================================================
        # GUIDs
        # ============================================================

        $AllPropertiesGUID = [GUID]'00000000-0000-0000-0000-000000000000'
        $EnrollGUID = [GUID]'0e10c968-78fb-11d2-90d4-00c04f79dc55'

        $Allow = [System.Security.AccessControl.AccessControlType]::Allow

        # ============================================================
        # Build AccessRule
        # ============================================================

        $AccessRule = switch ($AceType) {

            'Enroll' {
                @(
                    New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
                        $AuthenticatedUsers, $ExtendedRight, $Allow, $EnrollGUID

                    New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
                        $AuthenticatedUsers, $GenericRead, $Allow, $AllPropertiesGUID
                )
            }

            'FullControl' {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
                    $AuthenticatedUsers, $GenericAll, $Allow, $AllPropertiesGUID
            }

            'GenericAll' {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
                    $AuthenticatedUsers, $GenericAll, $Allow, $AllPropertiesGUID
            }

            'WriteProperty' {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
                    $AuthenticatedUsers, $WriteProperty, $Allow, $AllPropertiesGUID
            }
        }
    }

    process {

        foreach ($name in $TemplateName) {

            Write-Verbose "Processing template: $name"

            $TemplateObject = New-Object System.DirectoryServices.DirectoryEntry(
                "LDAP://$Server/CN=$name,$TemplateContainer"
            )

            try {
                $ACL = $TemplateObject.ObjectSecurity
            }
            catch {
                throw "Could not read ACL from template '$name' on $pdc. $_"
            }

            foreach ($ace in $AccessRule) {
                $ACL.AddAccessRule($ace)
            }

            try {
                $TemplateObject.ObjectSecurity = $ACL
                $TemplateObject.CommitChanges()
                Write-Verbose "Successfully updated template '$name' on $pdc"
            }
            catch {
                $msg = $_.Exception.Message
                if ($_.Exception.InnerException) {
                    $msg += "`nInnerException: $($_.Exception.InnerException.Message)"
                }

                throw "Failed to apply ACL to template '$name' on $pdc.`n$msg"
            }
        }
    }
}