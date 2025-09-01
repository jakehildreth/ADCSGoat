function Set-AGTemplateProperty {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$TemplateName,
        [Parameter(ValueFromPipeline, Mandatory)]
        [hashtable]$Properties
    )

    begin {
        Add-Type -AssemblyName System.DirectoryServices
        # Get the Configuration partition
        $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
        $ConfigurationPartition = $rootDSE.configurationNamingContext
    }

    process {
        # Connect to the specific template
        $TemplateDN = "CN=$TemplateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigurationPartition"
        $Template = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$TemplateDN")

        try {
            # Apply $Properties to the object
            $Template.Properties['displayName'].Add($TemplateName)
            foreach ($property in $Properties.GetEnumerator()) {
                Write-Verbose "Attempting to set $($property.Name) on $TemplateName to: $($property.Value)"
                # Each $property could be of a different type, and each type has to be applied differently.
                if ($property.Value -is [System.Collections.ICollection] -and $property.Value -isnot [byte[]]) {
                    # Handle different collection types (ArrayList, Array, etc.), but not byte arrays

                    # Clear existing values
                    $Template.Properties[$property.Key].Clear()

                    # Iterate through the collection and add each value individually
                    foreach ($value in $property.Value) {
                        $Template.Properties[$property.Key].Add($value)
                    }
                } else {
                    # Handle byte arrays and single values (strings, integers, etc.) simply
                    $Template.Properties[$property.Key].Value = $property.Value
                }
            }
            $Template.CommitChanges()
        } finally {
            # if ($Template) { $Template.Dispose() }
        }
    }
}
