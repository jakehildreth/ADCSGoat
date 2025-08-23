function New-AGBlankTemplateObject {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        # TODO Add input validation to $TemplateName and $name
        # TODO Generisize to create any objectClass in any location
        [string[]]$TemplateName
    )

    begin {
        # Load the S.DS
        Add-Type -AssemblyName System.DirectoryServices

        # Get the Configuration partition automatically via RootDSE
        $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
        $ConfigurationPartition = $rootDSE.configurationNamingContext
        $TemplatesContainer = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigurationPartition"
        $TemplatePath = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$TemplatesContainer")
    }

    process {
        Write-Output $TemplateName -PipelineVariable name | ForEach-Object {
            $success = $false
            while (-not $success) {
                try {
                    $newTemplate = $TemplatePath.Children.Add("CN=$name", "pKICertificateTemplate")
                    $newTemplate.CommitChanges()
                    $success = $true
                } catch {
                    Write-Error "That template name ($name) is invalid. Please enter a new name."
                    $name = Read-Host -Prompt 'New Template Name'
                }
            }
        }
    }
}
