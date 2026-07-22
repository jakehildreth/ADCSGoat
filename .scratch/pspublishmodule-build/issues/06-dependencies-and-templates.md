## Question

How should PSPublishModule 2.0.27 handle ADCSGoat's dependencies (`PSCertutil`, possibly `AutomatedLab`) and the `Private/Template/*.{json,xml,ps1}` support files?

Research the PSPublishModule configuration options (`New-ConfigurationModule`, `New-ConfigurationModuleSkip`, file inclusion, approved modules, external dependencies) that map to ADCSGoat's actual module contents. Report recommended settings for `Build-Module.ps1`.

**Constraint:** `PSCertutil` must be vendored into the built module, following the Locksmith2 pattern.

## Answer

See full findings in [`research/06-findings.md`](../research/06-findings.md). Key decisions:

- **PSCertutil** — vendor post-build using the Locksmith2 three-phase pattern: install for build-time analysis, `New-ConfigurationModuleSkip -IgnoreModuleName 'PSCertutil'` inside `Build-Module {}`, then `Save-Module` + `Update-ModuleManifest -NestedModules` in a post-build script. Pin to `0.0.3`.
- **AutomatedLab + PSFramework** — skip via `New-ConfigurationModuleSkip`; treat as soft, optional runtime deps. Do not include in `RequiredModules`.
- **Built-in modules** — declare `Microsoft.PowerShell.Utility`, `Microsoft.PowerShell.Management`, `Microsoft.PowerShell.Security` as `ExternalModule`.
- **Private/Template/*.xml** — runtime-critical; PSPublishModule does not copy them, so the post-build step must `Copy-Item` them into the artefact.
- **Do not enable `MergeModuleOnBuild`** until `Install-ADCSGoat.ps1`'s `$PSScriptRoot`-relative path to the XML templates is fixed.
- **Do not use `New-ConfigurationPublish`** inside `Build-Module {}`; publish via `Publish-Module -Path $ArtefactRoot` after vendoring.

Type: research
Status: resolved
