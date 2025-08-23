function Deploy-AdcsGoat {
    $TemplateNames = @(
        'ESC1'
        'ESC2'
        'ESC3c1'
        'ESC3c2'
        'ESC4'
        'ESC9'
    )

    # We need blank template objects.
    $TemplateNames | ForEach-Object {
        New-AGBlankTemplateObject -TemplateName $_
    }

    # We need to assign properties to the blank template objects to turn them into real templates.
    $TemplateNames.Where( { $_ -ne 'ESC4' } ) | ForEach-Object {
        $PropertiesPath = Join-Path -Path ".\Research" -ChildPath "${_}.xml"
        $Properties = Import-Clixml -Path $PropertiesPath
        Set-AGTemplateProperty -TemplateName $_ -Properties $Properties
    }

    # We need to grant low privileged users Enroll right on template objects to turn them into ESC issues.
    $TemplateNames.Where( { $_ -ne 'ESC4' } ) | ForEach-Object {
        Set-AGTemplateAce -TemplateName $_ -AceType Enroll
    }

    # We need to grant low privileged users Full Control over a template object to turn it into an ESC4.
    $TemplateNames.Where( { $_ -eq 'ESC4' } ) | ForEach-Object {
        Set-AGTemplateAce -TemplateName $_ -AceType GenericAll
    }
}

