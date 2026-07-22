Status: ready-for-agent

# Spec: Migrate ADCSGoat Build System to PSPublishModule 2.0.27

## Problem Statement

ADCSGoat currently builds and publishes using psake plus the PowerShellBuild module. This toolchain is aging, harder to maintain, and inconsistent with the author's other PowerShell modules (Locksmith2 and Stepper), which use PSPublishModule 2.0.27. The existing build also relies on a manual SemVer bump and a BuildHelpers-based version-bump check in CI, adding friction to every release.

## Solution

Replace the psake/PowerShellBuild build pipeline with PSPublishModule 2.0.27. Adopt the directory structure and `Build-Module.ps1` pattern used by Locksmith2 and Stepper: module files at the repo root, a `Build/` directory containing the build script and a post-build vendoring script, CalVer versioning, and a GitHub Actions workflow that installs PSPublishModule and publishes the built artefact.

## User Stories

1. As a maintainer, I want the module to build with a single `Build-Module.ps1` script, so that local builds and CI use the same code path.
2. As a maintainer, I want versioning to use CalVer (`yyyy.M.dHHmm`), so that every qualifying push produces a unique, deterministic version without manual bumps.
3. As a publisher, I want CI to build and publish the fully vendored artefact directory, so that users receive a module that includes its required dependencies.
4. As a user, I want `Install-ADCSGoat` and `Uninstall-ADCSGoat` to keep working after the build migration, so that the module still configures the lab correctly.
5. As a contributor, I want existing Pester tests to continue running from a `Tests/` directory, so that the test layout matches the other modules in the ecosystem.
6. As a maintainer, I want `PSCertutil` vendored into the published module, so that consumers do not need to install it separately.
7. As a maintainer, I want `AutomatedLab` and `PSFramework` treated as soft, optional dependencies, so that users who only need `Install-ADCSGoat` are not forced to install a lab framework.
8. As a user, I want the module's help documentation files preserved, so that existing command help remains available.
9. As a maintainer, I want the build artefact to include the template data files used by `Install-ADCSGoat`, so that certificate template properties are loaded correctly at runtime.
10. As a publisher, I want CI to install PSPublishModule 2.0.27 specifically, so that builds remain reproducible and do not accidentally pick up breaking changes from newer versions.

## Implementation Decisions

- **Build tool**: Use PSPublishModule 2.0.27 as the build engine, replacing psake and PowerShellBuild.
- **Build script location**: Add a `Build/` directory at the repo root containing `Build-Module.ps1` and a companion post-build script for vendoring and publishing.
- **Module layout**: Move the module's `.psd1`, `.psm1`, `Public/`, and `Private/` directories from the nested `./ADCSGoat/` directory to the repo root, matching Locksmith2 and Stepper.
- **Versioning**: Switch from SemVer to CalVer. `ModuleVersion` defaults to `yyyy.M.dHHmm`; an optional `-Prerelease` parameter appends a prerelease tag.
- **Manifest ownership**: PSPublishModule owns the manifest content via `New-ConfigurationManifest` inside `Build-Module.ps1`. The root `.psd1` becomes build output, not the source of truth.
- **Built-in dependencies**: Declare `Microsoft.PowerShell.Utility`, `Microsoft.PowerShell.Management`, and `Microsoft.PowerShell.Security` as external modules.
- **Vendored dependency**: PSCertutil is vendored post-build using the Locksmith2 pattern: install it for build-time analysis, skip it during PSPublishModule's static analysis, then `Save-Module` into the artefact and patch the built manifest's `NestedModules`.
- **Soft dependencies**: `AutomatedLab` and `PSFramework` are skipped by PSPublishModule's analyser and remain optional runtime requirements for `Deploy-AGInfrastructure` only.
- **Template data files**: The XML template files under `Private/Template/` are runtime-critical. Because PSPublishModule does not copy non-`.ps1` files from `Private/` into the artefact, the post-build step must copy them.
- **Module merge**: Do not enable `MergeModuleOnBuild` until `Install-ADCSGoat`'s `$PSScriptRoot`-relative path to the XML templates is corrected to resolve from the merged module root.
- **Formatting configuration**: Format `DefaultPSM1` and `OnMergePSD1` (minimal style). Avoid `DefaultPSD1` formatting due to the known PSScriptAnalyzer CRLF/LF bug.
- **Documentation generation**: Disable PSPublishModule's documentation generation and preserve the existing hand-written help files.
- **Directory naming**: Rename `tests/` to `Tests/` and `docs/` to `Docs/` to match the reference module conventions.
- **Publishing**: Do not configure publishing inside the `Build-Module {}` scriptblock; publish via `Publish-Module -Path <artefact-root>` in the post-build step so the vendored copy ships.
- **CI workflow**: Rewrite the GitHub Actions workflow to install PSPublishModule 2.0.27 and PSCertutil, run Pester from `Tests/`, then invoke `Build-Module.ps1 -PublishToPSGallery`. Remove the BuildHelpers version-bump gate.

## Testing Decisions

- **Build command seam**: The build script must run on a clean machine and produce Unpacked and Packed artefacts without errors.
- **Artefact load seam**: Importing the built `.psd1` from the Unpacked artefact must succeed and export the expected public functions.
- **Vendored dependency seam**: The built artefact must contain a `Modules/PSCertutil/` directory, and the exported functions that call PSCertutil must resolve those commands at runtime.
- **Template file seam**: `Install-ADCSGoat` must successfully import the CliXml template files from the built artefact.
- **Test seam**: Existing Pester tests must continue to pass after the directory rename and build changes.
- **CI seam**: A push to `main` that touches module files must trigger the workflow and complete the build/publish step successfully.

Tests should exercise external behavior (the module builds, imports, and its commands work) rather than implementation details (the exact contents of the merged PSM1 or the internal file layout of the artefact).

## Out of Scope

- Changing the functionality of any ADCSGoat cmdlet.
- Rewriting Pester tests from scratch.
- Moving `Deploy-AGInfrastructure` out of the module or changing the `AutomatedLab`/`PSFramework` dependency model.
- Enabling `MergeModuleOnBuild` in this migration; that is deferred until the template path is corrected.
- Switching away from GitHub Actions or the PowerShell Gallery.

## Further Notes

- The VS Code PowerShell Extension pre-loads PSScriptAnalyzer, which conflicts with PSPublishModule's internal import. The build script must re-invoke itself in a clean `pwsh -NoProfile` child process when running inside VS Code.
- The post-build vendoring script should pin PSCertutil to a tested version and bump it deliberately after verification, rather than pulling `Latest`.
- Because `MergeModuleOnBuild` is disabled for this migration, `Public/` and `Private/` source files will remain separate in the Unpacked artefact. This keeps the existing `$PSScriptRoot`-relative template path working.
