# Declare AutomatedLab and PSFramework installation dependencies

Archived local record. Canonical ticket: [Declare AutomatedLab and PSFramework installation dependencies](https://github.com/jakehildreth/ADCSGoat/issues/18).

Type: research
Label: wayfinder:research
Status: resolved
Parent: [Plan ADCSGoat deployment defaults and installation dependencies](../map.md)

## Question

How should the source manifest and PSPublishModule build declare AutomatedLab and PSFramework so that `Install-Module ADCSGoat` installs both and the published artifact preserves the declarations?

## Required outcome

Both modules must install through standard package dependency metadata, not an import-time installation script. The user explicitly requested both; splitting infrastructure into another optional package is outside this effort.

## Repository evidence

- `ADCSGoat.psd1`: `RequiredModules` and `ExternalModuleDependencies` currently list only built-in Microsoft modules.
- `Build/Build-Module.ps1`: `New-ConfigurationModule -Type ExternalModule` lists those built-ins; `New-ConfigurationModuleSkip` explicitly excludes AutomatedLab and PSFramework.
- `Build/Invoke-AGPostBuildPublish.ps1`: preserves PSCertutil vendoring and publishes from the artifact path after patching `NestedModules`.
- `Public/Deploy-AGInfrastructure.ps1`: uses AutomatedLab commands, PSFramework commands, and PSFramework validation attributes.

## Acceptance for the decision

- Cite PowerShellGet/PowerShell Gallery dependency semantics and PSPublishModule configuration behavior.
- Identify exactly which declarations and skip entries must change in source and build output.
- Explain the difference between `RequiredModules` and `ExternalModuleDependencies`; do not accidentally mark Gallery dependencies as external.
- Recommend any version constraints only from supported compatibility evidence.
- State the impact on `Import-Module ADCSGoat`, including use on an existing CA that does not deploy infrastructure.
- Define isolated package-resolution and import smoke checks. Do not install dependencies into the user's environment or publish a package during planning.

## Answer

Declare name-only `AutomatedLab` and `PSFramework` entries in source `RequiredModules` and in `New-ConfigurationModule -Type RequiredModule` build configuration. Remove those names from `New-ConfigurationModuleSkip`, leaving PSCertutil. Keep both Gallery dependencies out of `ExternalModuleDependencies`; preserve the existing built-in declarations, PSCertutil 0.0.3 vendoring, and publication from the finalized Unpacked path. No new version constraints have a demonstrated compatibility basis.

`Install-Module` installs the dependency graph but does not import it. `Import-Module ADCSGoat` subsequently imports both requirements and AutomatedLab's transitive graph. AutomatedLab initialization includes network and ProgramData activity even on an existing-CA-only host. Isolated import checks are a release gate, not an observed pass.

The versioned PSPublishModule 2.0.27 source rebuilds `RequiredModules` from build configuration, so a source-manifest-only change will not survive the build. Its API differs from newer publisher documentation. PowerShellGet v2 excludes names marked external from package dependencies; adding the requested packages to that external list would defeat automatic installation.

Acceptance: compare source/generated/finalized/package dependency sets and actual `.nuspec` entries; then prove ordinary installation in a disposable repository/account with real dependencies, followed by manifest-based imports on Windows PowerShell 5.1 and a supported PowerShell 7 host. Include existing-CA-only and offline-after-install cases. These checks have not run.

Separate finding: Packed output precedes the existing vendoring hook. Do not assume it equals the published Unpacked tree; fixing that pre-existing vendor/payload discrepancy is outside this dependency-metadata decision.

Evidence and exact configuration examples: [ADCSGoat installation dependencies: research and configuration decision](../research/module-dependencies.md).
