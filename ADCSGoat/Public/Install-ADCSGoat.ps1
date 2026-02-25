function Install-ADCSGoat {
    [CmdletBinding()]
    param (
        [switch]$Randomize,
        [string]$TemplatePrefix = "AG",
        [string]$Server
    )

    if ([string]::IsNullOrEmpty($Server)) {
        $Server = [System.Net.Dns]::GetHostEntry($env:LOGONSERVER.TrimStart('\')).HostName
    }

    #region template issues
    $Templates = @(
        @{Name = "${TemplatePrefix}ESC1"; ESC = 'ESC1' }
        @{Name = "${TemplatePrefix}ESC2"; ESC = 'ESC2' }
        @{Name = "${TemplatePrefix}ESC3c1"; ESC = 'ESC3c1' }
        @{Name = "${TemplatePrefix}ESC3c2"; ESC = 'ESC3c2' }
        @{Name = "${TemplatePrefix}ESC4"; ESC = 'ESC4' }
        @{Name = "${TemplatePrefix}ESC9"; ESC = 'ESC9' }
    )

    # What: Create blank template objects.
    # Why:
    $Templates | ForEach-Object {
        Write-Verbose "Creating blank template object: $($_.Name)"
        New-AGBlankTemplateObject -TemplateName $_.Name -Server $Server
    }

    # What: Assign properties to the blank template objects to turn them into real templates with vulnerable configs.
    # Why:
    $Templates | ForEach-Object {
        Write-Verbose "Assigning $($_.ESC) configuration to: $($_.Name)"
        $PropertiesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\Private\Template\$($_.ESC).xml"
        $Properties = Import-Clixml -Path $PropertiesPath
        Set-AGTemplateProperty -TemplateName $_.Name -Properties $Properties -Server $Server
    }

    # What: Grant low privileged users Enroll right on template objects to turn them into ESC issues (except ESC4)
    # Why:
    $Templates.Where( { $_.ESC -ne 'ESC4' } ) | ForEach-Object {
        Write-Verbose "Granting Authenticated Users Enroll rights on: $($_.Name)"
        Set-AGTemplateAce -TemplateName $_.Name -AceType Enroll -Server $Server
    }

    # What: Grant low privileged users Full Control over a template object to turn it into an ESC4.
    # Why:
    $Templates.Where( { $_.ESC -eq 'ESC4' } ) | ForEach-Object {
        Write-Verbose "Granting Authenticated Users Full Control of: $($_.Name)"
        Set-AGTemplateAce -TemplateName $_.Name -AceType GenericAll -Server $Server
    }
    #endregion template issues

    #region ca issues
    # What: Get the list of all Enrollment Services, generate their full CA names, then add the name to the CA object
    # Why:
    $EnrollmentServices = Find-AGEnrollmentService
    $EnrollmentServices | Set-AGEnrollmentServiceFullName

    # What: Enable ESC5 configuration on all CAs.
    # Why:
    $EnrollmentServices | ForEach-Object {
        Write-Verbose "Granting Authenticated Users Full Control of: $($_.FullName)"
        # Enable-PSCEditFlag -CAFullName $_.FullName -Flag EDITF_ATTRIBUTESUBJECTALTNAME2
    }

    # What: Enable ESC6 configuration on all CAs.
    # Why:
    $EnrollmentServices | ForEach-Object {
        Write-Verbose "Assigning ESC6 configuration to: $($_.Name)"
        Enable-PSCEditFlag -CAFullName $_.FullName -Flag EDITF_ATTRIBUTESUBJECTALTNAME2
    }

    # What: Enable ESC11 configuration on all CAs.
    # Why:

    $EnrollmentServices | ForEach-Object {
        Write-Verbose "Assigning ESC11 configuration to: $($_.Name)"
        Disable-PSCInterfaceFlag -CAFullName $_.FullName -Flag IF_ENFORCEENCRYPTICERTREQUEST
    }

    # What: Publish Certificate Templates
    # Why:
    $EnrollmentServices = Find-AGEnrollmentService
    $Templates | ForEach-Object {
        Write-Verbose "Publish $($_.Name) to: $($EnrollmentServices.Path)"
        Publish-AGCertifcateTemplate  -TemplateName $_.Name -EnrollmentService $EnrollmentServices.Path -Server $Server
    }

    #endregion ca issues
}

