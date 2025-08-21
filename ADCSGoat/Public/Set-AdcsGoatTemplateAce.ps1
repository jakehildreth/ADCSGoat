function Set-AdcsGoatTemplateAce {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [string[]]$TemplateName,
        [Parameter(Mandatory)]
        [ValidateSet('Enroll','FullControl','GenericAll','WriteProperty')]
        [string]$AceType
    )

    begin {
        # Load the S.DS
        Add-Type -AssemblyName System.DirectoryServices

        # Get the Configuration partition automatically via RootDSE
        $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
        $ConfigurationPartition = $rootDSE.configurationNamingContext
        $TemplateContainer = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigurationPartition"

        # Define principals for use in ACEs
        # $Administrators = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
        $AuthenticatedUsers = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-11')
        
        # Define Active Directory Rights for use in ACEs
        $ExtendedRight = [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
        $GenericAll = [System.DirectoryServices.ActiveDirectoryRights]::GenericAll
        $GenericRead = [System.DirectoryServices.ActiveDirectoryRights]::GenericRead
        # $ReadProperty = [System.DirectoryServices.ActiveDirectoryRights]::ReadProperty
        # $WriteOwner = [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner
        $WriteProperty = [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty

        # Define GUIDs for use in ACEs
        # TODO get the ms-PKI GIDs
        $AllPropertiesGUID = [GUID]'00000000-0000-0000-0000-000000000000'
        $EnrollGUID        = [GUID]'0e10c968-78fb-11d2-90d4-00c04f79dc55'
        # $AutoEnrollGUID    = [GUID]'a05b8cc2-17bc-4802-a710-e7c15ab866a2'

        # Define Access Control Type for use in ACEs
        $Allow = [System.Security.AccessControl.AccessControlType]::Allow
        # $Deny = [System.Security.AccessControl.AccessControlType]::Deny

        $AccessRule = switch -Regex ($AceType) {
            'Enroll' {
                @(
                    New-Object System.DirectoryServices.ActiveDirectoryAccessRule $AuthenticatedUsers, $ExtendedRight, $Allow, $EnrollGUID
                    New-Object System.DirectoryServices.ActiveDirectoryAccessRule $AuthenticatedUsers, $GenericRead, $Allow, $AllPropertiesGUID
                )
            } 
            'FullControl|GenericAll' {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule $AuthenticatedUsers, $GenericAll, $Allow, $AllPropertiesGUID
            }
            'WriteProperty' {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule $AuthenticatedUsers, $WriteProperty, $Allow, $AllPropertiesGUID
            }
        }
    }

    process {
        Write-Output $TemplateName -PipelineVariable name | ForEach-Object {
            $success = $false
            $TemplateObject = New-Object System.DirectoryServices.DirectoryEntry("LDAP://CN=$name,$TemplateContainer")
            
            while (-not $success) {
                # Get the current ACL
                $ACL = try {
                    $TemplateObject.ObjectSecurity
                } catch {
                    throw "Could not collect ACL from $name (CN=$name,$TemplateContainer). Do you have rights to read the template object?"
                }
                
                # Add each access rule to the ACL
                Write-Output $AccessRule -PipelineVariable ace | ForEach-Object {
                    $ACL.AddAccessRule($ace)
                }

                try {
                    $TemplateObject.ObjectSecurity = $ACL
                    $TemplateObject.CommitChanges()
                    $success = $true
                } catch {
                    throw "Could not apply new ACL to $name (CN=$name,$TemplateContainer). Do you have rights to write to the template object?"
                    # exit
                }
            }
        }
    }
}
