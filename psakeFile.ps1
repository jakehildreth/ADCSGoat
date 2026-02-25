properties {
    # Set this to $true to create a module with a monolithic PSM1
    $PSBPreference.Build.CompileModule = $false
    $PSBPreference.Help.DefaultLocale = 'en-US'
    $PSBPreference.Help.GenerateMarkdown = $false
    $PSBPreference.Test.OutputFile = 'out/testResults.xml'
    $PSBPreference.Test.ScriptAnalysisSettingsPath = './tests/ScriptAnalyzerSettings.psd1'
    $PSBPreference.Publish.PSRepositoryApiKey = $env:PSGALLERY_API_KEY
}

task Default -depends Test

task Test -FromModule PowerShellBuild -minimumVersion '0.6.1'
