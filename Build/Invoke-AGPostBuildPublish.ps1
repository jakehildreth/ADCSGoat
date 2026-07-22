function Invoke-AGPostBuildPublish {
    <#
    .SYNOPSIS
    Vendors PSCertutil into the unpacked artefact and optionally publishes to PSGallery.

    .DESCRIPTION
    Copies a pinned version of PSCertutil into the Modules\ subfolder of the unpacked
    artefact, patches NestedModules in the PSD1, copies the runtime-critical template
    support files into Private\Template, then — if requested — publishes directly from
    the artefact path so that the vendored dependency ships.

    Publishing via -Path bypasses PSModulePath, ensuring what ships to PSGallery matches
    exactly what is in the artefact directory rather than the pre-vendoring source tree.

    .PARAMETER ArtefactRoot
    Full path to the unpacked module artefact directory (contains ADCSGoat.psd1).

    .PARAMETER PublishToPSGallery
    When present, publishes the module to PSGallery after vendoring.

    .PARAMETER PSGalleryAPIKey
    NuGet API key in clear text. Used when running in CI via a secret environment variable.

    .PARAMETER PSGalleryAPIPath
    Path to a file containing the NuGet API key. Used for local developer workflows.

    .EXAMPLE
    Invoke-AGPostBuildPublish -ArtefactRoot 'C:\ADCSGoat\Artefacts\Unpacked\ADCSGoat' -PublishToPSGallery -PSGalleryAPIKey $env:PSGALLERY_API_KEY

    .EXAMPLE
    Invoke-AGPostBuildPublish -ArtefactRoot 'C:\ADCSGoat\Artefacts\Unpacked\ADCSGoat' -PublishToPSGallery -PSGalleryAPIPath 'C:\Secrets\psgallery.txt'

    .OUTPUTS
    None. Writes host/verbose messages only.

    .NOTES
    Pinned vendor versions are defined inside this function. Bump them here when updating deps.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ArtefactRoot,

        [Parameter()]
        [switch]$PublishToPSGallery,

        [Parameter()]
        [string]$PSGalleryAPIKey,

        [Parameter()]
        [string]$PSGalleryAPIPath
    )

    if (-not (Test-Path -Path $ArtefactRoot)) {
        Write-Error "Artefact root '$ArtefactRoot' does not exist. Build-Module may have failed to produce the Unpacked artefact."
        return
    }

    $moduleName = 'ADCSGoat'
    $sourceRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..')

    # ── Vendor PSCertutil ──────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '[i] Vendoring dependencies into artefact' -ForegroundColor Cyan

    $modulesTarget = Join-Path $ArtefactRoot 'Modules'
    New-Item -ItemType Directory -Path $modulesTarget -Force | Out-Null

    $vendorVersions = [ordered] @{
        PSCertutil = '0.0.3'
    }

    $nestedEntries = @()
    foreach ($depName in $vendorVersions.Keys) {
        $pinned = $vendorVersions[$depName]
        $saveParams = @{
            Name  = $depName
            Path  = $modulesTarget
            Force = $true
        }
        if ($pinned) { $saveParams['RequiredVersion'] = $pinned }
        $versionLabel = if ($pinned) { " $pinned" } else { ' (latest)' }
        Write-Host "   [>] Saving $depName$versionLabel from PSGallery..." -ForegroundColor Yellow
        Save-Module @saveParams

        $versionFolder = Get-ChildItem -Path (Join-Path $modulesTarget $depName) -Directory |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if (-not $versionFolder) {
            Write-Error "Could not locate vendored $depName version folder under $modulesTarget."
            return
        }
        Write-Host "   [+] Vendored $depName $($versionFolder.Name)" -ForegroundColor Green
        $nestedEntries += "Modules\$depName\$($versionFolder.Name)\$depName.psm1"
    }

    $psd1 = Join-Path $ArtefactRoot "$moduleName.psd1"
    if (Test-Path -Path $psd1) {
        Update-ModuleManifest -Path $psd1 -NestedModules $nestedEntries
        Write-Host "[+] $moduleName.psd1 patched - NestedModules = $($nestedEntries -join ', ')" -ForegroundColor Green
    } else {
        Write-Warning "Could not find built manifest at $psd1; skipping NestedModules patch."
    }

    # ── Copy runtime-critical template support files ───────────────────────────
    # PSPublishModule only copies .ps1 files from Private/ by default. The XML
    # (and JSON/PS1) template data files are required at runtime, so copy them
    # into the unpacked artefact here.
    Write-Host ''
    Write-Host '[i] Copying template support files into artefact' -ForegroundColor Cyan

    $sourceTemplateDir = Join-Path $sourceRoot 'Private' 'Template'
    $targetTemplateDir = Join-Path $ArtefactRoot 'Private' 'Template'
    if (Test-Path -Path $sourceTemplateDir) {
        New-Item -ItemType Directory -Path $targetTemplateDir -Force | Out-Null
        $templateFiles = Get-ChildItem -Path $sourceTemplateDir -File
        foreach ($file in $templateFiles) {
            Copy-Item -Path $file.FullName -Destination $targetTemplateDir -Force
            Write-Host "   [+] Copied $($file.Name)" -ForegroundColor Green
        }
    } else {
        Write-Warning "Source template directory not found: $sourceTemplateDir"
    }

    # ── Copy about_* help files into the module-root culture folder ────────────
    # PowerShell's about-topic lookup expects these at <module-root>\en-US\ rather
    # than under Docs\en-US\, so copy them from the source Docs\en-US\ location.
    $sourceEnUS = Join-Path $sourceRoot 'Docs' 'en-US'
    $targetEnUS = Join-Path $ArtefactRoot 'en-US'
    if (Test-Path -Path $sourceEnUS) {
        New-Item -ItemType Directory -Path $targetEnUS -Force | Out-Null
        $aboutFiles = Get-ChildItem -Path $sourceEnUS -Filter 'about_*.help.txt'
        foreach ($file in $aboutFiles) {
            Copy-Item -Path $file.FullName -Destination $targetEnUS -Force
            Write-Host "   [+] Copied $($file.Name)" -ForegroundColor Green
        }
    }

    # ── Publish from artefact path (not from PSModulePath) ────────────────────
    if (-not $PublishToPSGallery) {
        return
    }

    Write-Host ''
    Write-Host '[i] Publishing to PSGallery' -ForegroundColor Cyan

    if ($PSGalleryAPIKey) {
        $apiKey = $PSGalleryAPIKey
    } elseif ($PSGalleryAPIPath) {
        $apiKey = Get-Content -Path $PSGalleryAPIPath -ErrorAction Stop -Encoding UTF8 |
            Select-Object -First 1
    } else {
        Write-Host '[x] -PublishToPSGallery specified but neither -PSGalleryAPIKey nor -PSGalleryAPIPath was provided.' -ForegroundColor Red
        Write-Error '-PublishToPSGallery was specified but neither -PSGalleryAPIKey nor -PSGalleryAPIPath was provided.'
        return
    }

    if ($PSCmdlet.ShouldProcess($ArtefactRoot, 'Publish-Module to PSGallery')) {
        Write-Host "   [>] Calling Publish-Module -Path $ArtefactRoot" -ForegroundColor Yellow
        $publishParams = @{
            Path        = $ArtefactRoot
            NuGetApiKey = $apiKey
            Repository  = 'PSGallery'
            Force       = $true
            ErrorAction = 'Stop'
        }
        Publish-Module @publishParams
        Write-Host "[+] Published $moduleName to PSGallery successfully" -ForegroundColor Green
    }
}
