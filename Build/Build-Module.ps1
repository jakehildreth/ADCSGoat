param (
    # A CalVer string if you need to manually override the default yyyy.M.dHHmm version string.
    [string]$CalVer,
    # A prerelease tag to append to the module version (e.g., 'alpha', 'beta', 'rc1').
    [string]$Prerelease,
    [switch]$PublishToPSGallery,
    [string]$PSGalleryAPIPath,
    [string]$PSGalleryAPIKey
)

# The VS Code PowerShell Extension pre-loads PSScriptAnalyzer into the host
# process. PSPublishModule imports PSScriptAnalyzer internally, and loading a
# second copy of its assembly into the same appdomain throws an assembly-already-
# loaded error. Re-invoke in a clean pwsh -NoProfile child process to avoid it.
if ($Host.Name -eq 'Visual Studio Code Host' -or
    $null -ne [System.AppDomain]::CurrentDomain.GetAssemblies().Where({
            $_.GetName().Name -eq 'Microsoft.Windows.PowerShell.ScriptAnalyzer'
        }, 'First')[0]) {
    Write-Host 'Re-invoking in a clean pwsh process to avoid PSScriptAnalyzer assembly conflict...'
    $passThrough = @('-NoProfile', '-File', $PSCommandPath)
    if ($CalVer) { $passThrough += '-CalVer'; $passThrough += $CalVer }
    if ($Prerelease) { $passThrough += '-Prerelease'; $passThrough += $Prerelease }
    if ($PublishToPSGallery) { $passThrough += '-PublishToPSGallery' }
    if ($PSGalleryAPIPath) { $passThrough += '-PSGalleryAPIPath'; $passThrough += $PSGalleryAPIPath }
    if ($PSGalleryAPIKey) { $passThrough += '-PSGalleryAPIKey'; $passThrough += $PSGalleryAPIKey }
    & pwsh @passThrough
    exit $LASTEXITCODE
}

if (Get-Module -Name 'PSPublishModule' -ListAvailable) {
    Write-Verbose 'PSPublishModule is installed.'
} else {
    Write-Verbose 'PSPublishModule is not installed. Attempting installation.'
    try {
        Install-Module -Name Pester -AllowClobber -Scope CurrentUser -SkipPublisherCheck -Force
        Install-Module -Name PSScriptAnalyzer -AllowClobber -Scope CurrentUser -Force
        Install-Module -Name PSPublishModule -MaximumVersion 2.0.27 -AllowClobber -Scope CurrentUser -Force
    } catch {
        Write-Error "PSPublishModule installation failed. $_"
    }
}

Import-Module -Name PSPublishModule -Force

# Ensure vendored dependencies are available so PSPublishModule can resolve
# function calls to their source module during analysis (required for
# New-ConfigurationModuleSkip -IgnoreModuleName to match correctly).
foreach ($depName in @('PSCertutil')) {
    if (-not (Get-Module -Name $depName -ListAvailable)) {
        Write-Host "Installing $depName for build-time analysis..."
        Install-Module -Name $depName -Scope CurrentUser -Force -AllowClobber
    }
}

$CopyrightYear = if ($Calver) { $CalVer.Split('.')[0] } else { (Get-Date -Format yyyy) }

Build-Module -ModuleName 'ADCSGoat' {
    # Always use 3-part CalVer: yyyy.M.dHHmm (e.g., 2026.7.220745)
    # Prerelease builds append the supplied tag to the version string.
    $moduleVersion = if ($CalVer) { $CalVer } else { (Get-Date -Format 'yyyy.M.dHHmm') }
    $Manifest = [ordered] @{
        ModuleVersion        = $moduleVersion
        CompatiblePSEditions = @('Desktop', 'Core')
        GUID                 = '9febf038-d9cc-40d2-915a-5a51f26b78e3'
        Author               = 'Jake Hildreth'
        CompanyName          = 'Gilmour Technologies Ltd'
        Copyright            = "(c) 2025 - $CopyrightYear Jake Hildreth, Gilmour Technologies Ltd. All rights reserved."
        Description          = 'A tiny module built for a single purpose: building a small and very insecure AD CS lab.'
        ProjectUri           = 'https://github.com/jakehildreth/ADCSGoat'
        PowerShellVersion    = '5.1'
        Tags                 = @('ADCS', 'ADCSGoat', 'CertificateServices', 'PKI', 'Lab', 'ActiveDirectory', 'Windows')
    }
    if ($Prerelease) {
        $Manifest['Prerelease'] = $Prerelease
    }
    New-ConfigurationManifest @Manifest

    New-ConfigurationModule -Type ExternalModule -Name @(
        'Microsoft.PowerShell.Utility',
        'Microsoft.PowerShell.Management',
        'Microsoft.PowerShell.Security'
    )

    # Skip modules that are either vendored post-build or are soft runtime
    # dependencies only used by Deploy-AGInfrastructure.
    New-ConfigurationModuleSkip -IgnoreModuleName 'PSCertutil', 'AutomatedLab', 'PSFramework'

    $ConfigurationFormat = [ordered] @{
        RemoveComments                              = $false

        PlaceOpenBraceEnable                        = $true
        PlaceOpenBraceOnSameLine                    = $true
        PlaceOpenBraceNewLineAfter                  = $true
        PlaceOpenBraceIgnoreOneLineBlock            = $false

        PlaceCloseBraceEnable                       = $true
        PlaceCloseBraceNewLineAfter                 = $true
        PlaceCloseBraceIgnoreOneLineBlock           = $false
        PlaceCloseBraceNoEmptyLineBefore            = $true

        UseConsistentIndentationEnable              = $true
        UseConsistentIndentationKind                = 'space'
        UseConsistentIndentationPipelineIndentation = 'IncreaseIndentationAfterEveryPipeline'
        UseConsistentIndentationIndentationSize     = 4

        UseConsistentWhitespaceEnable               = $true
        UseConsistentWhitespaceCheckInnerBrace      = $true
        UseConsistentWhitespaceCheckOpenBrace       = $true
        UseConsistentWhitespaceCheckOpenParen       = $true
        UseConsistentWhitespaceCheckOperator        = $true
        UseConsistentWhitespaceCheckPipe            = $true
        UseConsistentWhitespaceCheckSeparator       = $true

        AlignAssignmentStatementEnable              = $true
        AlignAssignmentStatementCheckHashtable      = $true

        UseCorrectCasingEnable                      = $true
    }
    # Format PSM1 files within the module.
    New-ConfigurationFormat -ApplyTo 'DefaultPSM1' -EnableFormatting -Sort None
    # Use a minimal PSD1 style when creating the merged manifest.
    # DefaultPSD1 is intentionally excluded: PSPublishModule rewrites the source
    # PSD1 during the build and produces mixed CRLF/LF endings, which causes
    # PSScriptAnalyzer to throw.
    New-ConfigurationFormat -ApplyTo 'OnMergePSD1' -PSD1Style 'Minimal'

    # Disable PSPublishModule documentation generation so existing hand-written
    # help files under Docs\ and en-US\ are preserved.
    New-ConfigurationDocumentation -Enable:$false -StartClean -UpdateWhenNew -PathReadme 'Docs\Readme.md' -Path 'Docs'

    New-ConfigurationImportModule -ImportSelf -ImportRequiredModules

    # MergeModuleOnBuild is disabled for this migration because
    # Install-ADCSGoat resolves template XML paths relative to $PSScriptRoot.
    # Enabling a merge would move that root and break template loading until
    # the path is corrected.
    New-ConfigurationBuild -Enable:$true -SignModule:$false -DeleteTargetModuleBeforeBuild -MergeModuleOnBuild:$false -DoNotAttemptToFixRelativePaths -UseWildcardForFunctions

    New-ConfigurationArtefact -Type Unpacked -Enable -Path "$PSScriptRoot\..\Artefacts\Unpacked"
    New-ConfigurationArtefact -Type Packed -Enable -Path "$PSScriptRoot\..\Artefacts\Packed" -IncludeTagName
}

# NOTE: Publishing is intentionally NOT configured inside Build-Module {}.
# PSPublishModule's Publish-Module call uses -Name (resolves from PSModulePath),
# which publishes the pre-vendoring copy of the module and excludes PSCertutil.
# We publish via -Path after vendoring instead.

# Post-build: vendor PSCertutil, copy template support files, patch the manifest,
# and optionally publish from the artefact path.
. "$PSScriptRoot\Invoke-AGPostBuildPublish.ps1"

$postBuildParams = @{
    ArtefactRoot       = Join-Path $PSScriptRoot '..' 'Artefacts' 'Unpacked' 'ADCSGoat'
    PublishToPSGallery = $PublishToPSGallery
}
if ($PSGalleryAPIKey) { $postBuildParams['PSGalleryAPIKey'] = $PSGalleryAPIKey }
if ($PSGalleryAPIPath) { $postBuildParams['PSGalleryAPIPath'] = $PSGalleryAPIPath }

Invoke-AGPostBuildPublish @postBuildParams
