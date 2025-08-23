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
        New-AdcsGoatBlankTemplateObject -TemplateName $_
    }

    # We need to assign properties to the blank template objects to turn them into real templates.
    $TemplateNames | ForEach-Object {
        $PropertiesPath = Join-Path -Path ".\Research" -ChildPath "${_}.xml" 
        $Properties = Import-Clixml -Path $PropertiesPath
        Set-AdcsGoatTemplateProperty -TemplateName $_ -Properties $Properties
    }

    # We need to grant low privileged users control over blank template objects to turn them into ESC issues.
    $TemplateNames | ForEach-Object {
        Set-AdcsGoatTemplateAce -TemplateName $_ -AceType Enroll
    }
}

 