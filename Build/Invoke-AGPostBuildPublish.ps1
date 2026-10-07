function Invoke-AGPostBuildPublish {
    <#
    .SYNOPSIS
    Vendors PSCertutil into the unpacked artefact and optionally publishes to PSGallery and GitHub.

    .DESCRIPTION
    Copies a pinned version of PSCertutil into the Modules\ subfolder of the unpacked
    artefact, patches NestedModules in the PSD1, copies the runtime-critical template
    support files into Private\Template, then — if requested — publishes directly from
    the artefact path so that the vendored dependency ships.

    Publishing via -Path bypasses PSModulePath, ensuring what ships to PSGallery matches
    exactly what is in the artefact directory rather than the pre-vendoring source tree.

    When a GitHub token is supplied and publishing is enabled, the vendored unpacked
    artefact is compressed into a zip and attached to a GitHub release. This ensures the
    GitHub release asset contains the same vendored dependency as the PSGallery publish.

    .PARAMETER ArtefactRoot
    Full path to the unpacked module artefact directory (contains ADCSGoat.psd1).

    .PARAMETER PublishToPSGallery
    When present, publishes the module to PSGallery after vendoring.

    .PARAMETER PSGalleryAPIKey
    NuGet API key in clear text. Used when running in CI via a secret environment variable.

    .PARAMETER PSGalleryAPIPath
    Path to a file containing the NuGet API key. Used for local developer workflows.

    .PARAMETER PublishToGitHub
    When present, creates a GitHub release and attaches the vendored artefact as a zip asset.

    .PARAMETER GitHubAPIKey
    GitHub personal access token in clear text. Used when running in CI via a secret environment variable.

    .PARAMETER GitHubAPIPath
    Path to a file containing the GitHub personal access token. Used for local developer workflows.

    .PARAMETER GitHubOwner
    GitHub owner (user or organization) for release publishing. Defaults to 'jakehildreth'.

    .PARAMETER GitHubRepository
    GitHub repository name for release publishing. Defaults to 'ADCSGoat'.

    .PARAMETER Prerelease
    Prerelease tag appended to the module version. When present, the GitHub release is marked as a prerelease.

    .PARAMETER GitHubSha
    Commit SHA to use as the GitHub release target_commitish. Defaults to $env:GITHUB_SHA.
    GitHub releases are only allowed when this value is provided.

    .EXAMPLE
    Invoke-AGPostBuildPublish -ArtefactRoot 'C:\ADCSGoat\Artefacts\Unpacked\ADCSGoat' -PublishToPSGallery -PSGalleryAPIKey $env:PSGALLERY_API_KEY

    .EXAMPLE
    Invoke-AGPostBuildPublish -ArtefactRoot 'C:\ADCSGoat\Artefacts\Unpacked\ADCSGoat' -PublishToPSGallery -PSGalleryAPIPath 'C:\Secrets\psgallery.txt'

    .EXAMPLE
    Invoke-AGPostBuildPublish -ArtefactRoot 'C:\ADCSGoat\Artefacts\Unpacked\ADCSGoat' -PublishToGitHub -GitHubAPIKey $env:GITHUB_TOKEN -Prerelease 'pre'

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
        [string]$PSGalleryAPIPath,

        [Parameter()]
        [switch]$PublishToGitHub,

        [Parameter()]
        [string]$GitHubAPIKey,

        [Parameter()]
        [string]$GitHubAPIPath,

        [Parameter()]
        [string]$GitHubOwner = 'jakehildreth',

        [Parameter()]
        [string]$GitHubRepository = 'ADCSGoat',

        [Parameter()]
        [string]$Prerelease,

        [Parameter()]
        [string]$GitHubSha = $env:GITHUB_SHA
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

    # region GitHub Release
    if (-not $PublishToGitHub) {
        return
    }

    if (-not ($GitHubAPIKey -or $GitHubAPIPath)) {
        Write-Host '[x] -PublishToGitHub specified but neither -GitHubAPIKey nor -GitHubAPIPath was provided.' -ForegroundColor Red
        Write-Error '-PublishToGitHub was specified but neither -GitHubAPIKey nor -GitHubAPIPath was provided.'
        return
    }

    if ([string]::IsNullOrEmpty($GitHubSha)) {
        Write-Host '[x] -PublishToGitHub was specified but -GitHubSha was not provided and $env:GITHUB_SHA is not set. GitHub releases must be created from GitHub Actions.' -ForegroundColor Red
        Write-Error '-PublishToGitHub was specified but -GitHubSha was not provided and $env:GITHUB_SHA is not set. GitHub releases must be created from GitHub Actions.'
        return
    }

    Write-Host ''
    Write-Host '[i] Creating GitHub release' -ForegroundColor Cyan

    if ($GitHubAPIKey) {
        $gitHubToken = $GitHubAPIKey
    } else {
        $gitHubToken = Get-Content -Path $GitHubAPIPath -ErrorAction Stop -Encoding UTF8 |
            Select-Object -First 1
    }

    if (-not (Test-Path -Path $psd1)) {
        Write-Error "Cannot determine module version for GitHub release; manifest not found at $psd1."
        return
    }

    $moduleVersion = (Import-PowerShellDataFile -Path $psd1).ModuleVersion
    $releaseTag = if ($Prerelease) { "$moduleVersion-$Prerelease" } else { $moduleVersion }
    $releaseName = "$moduleName $releaseTag"
    $zipName = "$moduleName-$releaseTag.zip"
    $zipPath = Join-Path (Split-Path $ArtefactRoot -Parent) $zipName
    $releaseUri = "https://api.github.com/repos/$GitHubOwner/$GitHubRepository/releases"

    if (-not $PSCmdlet.ShouldProcess($releaseUri, 'Create GitHub release')) {
        return
    }

    if (Test-Path -Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }

    $stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    $stagingPath = Join-Path $stagingRoot $moduleName
    New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null
    Get-ChildItem -Path $ArtefactRoot | Copy-Item -Destination $stagingPath -Recurse -Force

    Write-Host "   [>] Compressing vendored artefact to $zipName" -ForegroundColor Yellow
    Compress-Archive -Path $stagingPath -DestinationPath $zipPath -Force
    Write-Host "   [+] Release zip created at $zipPath" -ForegroundColor Green

    Remove-Item -Path $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue

    $releaseBody = "$moduleName release $releaseTag"
    $releaseData = @{
        tag_name               = $releaseTag
        target_commitish       = $GitHubSha
        name                   = $releaseName
        body                   = $releaseBody
        draft                  = $false
        prerelease             = [bool]$Prerelease
        generate_release_notes = $true
    } | ConvertTo-Json

    $headers = @{
        Authorization          = "Bearer $gitHubToken"
        Accept                 = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    Write-Host "   [>] Creating GitHub release $releaseTag" -ForegroundColor Yellow
    try {
        $release = Invoke-RestMethod -Uri $releaseUri -Method Post -Headers $headers -Body $releaseData -ContentType 'application/json'
        Write-Host "   [+] GitHub release created" -ForegroundColor Green

        $uploadUri = $release.upload_url -replace '{\?name,[^}]*}', "?name=$zipName"
        Write-Host "   [>] Uploading $zipName to GitHub release" -ForegroundColor Yellow
        Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $headers -InFile $zipPath -ContentType 'application/zip' | Out-Null
        Write-Host "   [+] Uploaded $zipName to GitHub release" -ForegroundColor Green
    } catch {
        Write-Host "   [x] GitHub release creation failed: $_" -ForegroundColor Red
        Write-Error $_
    }
}
# endregion
