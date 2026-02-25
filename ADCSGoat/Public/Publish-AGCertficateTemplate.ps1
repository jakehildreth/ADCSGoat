function Publish-AGCertifcateTemplate {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [string[]]$TemplateName,
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$EnrollmentService,
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$Server
    )

    begin {
        Add-Type -AssemblyName System.DirectoryServices
        $EnrollmentServiceObject = [ADSI]$EnrollmentService.Replace("LDAP://", "LDAP://$Server/")
    }

    process {

        if ($EnrollmentServiceObject.certificateTemplates -notcontains $TemplateName) {
            $EnrollmentServiceObject.PutEx(3, "certificateTemplates", @($TemplateName))
            $EnrollmentServiceObject.SetInfo()
            Write-Verbose "Template '$TemplateName' published."
        } else {
            Write-Verbose  "Template '$TemplateName' already published on CA!"
        }
    }
}


