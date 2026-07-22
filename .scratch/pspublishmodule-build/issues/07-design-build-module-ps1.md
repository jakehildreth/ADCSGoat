## Question

What should the `Build/Build-Module.ps1` configuration be for ADCSGoat?

Consolidate the decisions from the layout, versioning, manifest, tests, docs, and dependency/template research tickets into a concrete `Build-Module.ps1` design. Include parameter surface (`CalVer`, `Prerelease`, `PublishToPSGallery`, etc.), manifest settings, formatting, artefact paths, and publish configuration.

## Answer

Approved design for `Build/Build-Module.ps1`:

- Parameters: `CalVer`, `Prerelease`, `PublishToPSGallery`, `PSGalleryAPIPath`, `PSGalleryAPIKey`
- VS Code / PSScriptAnalyzer re-invocation guard at the top
- Pre-flight: install `PSCertutil` for build-time analysis
- `Build-Module -ModuleName 'ADCSGoat'` with:
  - CalVer `ModuleVersion` (or override via `-CalVer`); optional `-Prerelease`
  - Manifest metadata preserved from current `ADCSGoat.psd1` (GUID, author, company, description, project URI, PowerShell 5.1, tags)
  - `ExternalModule` for `Microsoft.PowerShell.Utility`, `Microsoft.PowerShell.Management`, `Microsoft.PowerShell.Security`
  - `New-ConfigurationModuleSkip` for `PSCertutil`, `AutomatedLab`, `PSFramework`
  - Formatting: `DefaultPSM1` enabled; `OnMergePSD1` minimal style; no `DefaultPSD1` (CRLF/LF bug)
  - Documentation generation disabled; paths point to `Docs\`
  - `ImportSelf` + `ImportRequiredModules`
  - `New-ConfigurationBuild` **without** `MergeModuleOnBuild` until `Install-ADCSGoat.ps1`'s `$PSScriptRoot` template path is fixed
  - Artefacts: `Artefacts\Unpacked` and `Artefacts\Packed\` with tag name
- Post-build: dot-source `Build/Invoke-AGPostBuildPublish.ps1` to vendor PSCertutil 0.0.3, patch artefact PSD1 `NestedModules`, copy `Private\Template\*.xml`, and optionally `Publish-Module -Path $ArtefactRoot`

Implementation of the file and its companion script is a separate execution step.

Type: grilling
Status: resolved
