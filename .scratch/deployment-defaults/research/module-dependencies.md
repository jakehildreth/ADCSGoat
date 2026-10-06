# ADCSGoat installation dependencies: research and configuration decision

Archived local record. Published report: [ADCSGoat installation dependencies: research and configuration decision](https://github.com/jakehildreth/ADCSGoat/issues/18#issuecomment-5968932907). Continue discussion in [Declare AutomatedLab and PSFramework installation dependencies](https://github.com/jakehildreth/ADCSGoat/issues/18).

Research date: 2026-10-03. Planning only; no production edits, dependency installation/saving/import, build, test, provisioning, or publishing was performed. The PSPublishModule 2.0.27 package was fetched and its source inspected **in memory only**, because the Gallery's rendered `.psm1` content endpoint returned HTTP 413. Installed AutomatedLab/PSFramework files were read without importing them.

## Recommended decision

Declare **both `AutomatedLab` and `PSFramework` as direct, unconditional `RequiredModules`**, in the source manifest **and** PSPublishModule build configuration. Keep only the existing three built-in Microsoft modules in `PrivateData.PSData.ExternalModuleDependencies`. Remove AutomatedLab and PSFramework from the module-skip list, leaving PSCertutil skipped because it remains vendored. Do not add an import-time installer, optional infrastructure package, dependency vendoring, or host-feature installation. This implements the ticket's explicit standard-package requirement rather than preserving the current “soft runtime dependencies” classification. [R1][R2][R3][R4][P1][P2][B1]

**Recommend name-only declarations for this planning cutover, with no new dependency version bounds.** The observed releases are AutomatedLab 5.61.0 and PSFramework 1.14.457; their manifests support ADCSGoat's declared minimum PowerShell 5.1, but availability/manifest metadata is not a tested oldest-compatible version or an end-to-end compatibility result. Do not turn those observed versions into compatibility constraints, and do not infer PowerShell 7 as a dependency requirement. Isolated package-resolution/import checks remain release gates. [R2][A1][F1][L1]

**User-visible tradeoff:** `Install-Module ADCSGoat` installs the dependency graph, while `Import-Module ADCSGoat` imports both dependencies and AutomatedLab's transitive requirements even on a machine that only uses existing AD CS. This is not lazy infrastructure-only loading. AutomatedLab initialization has concrete network/filesystem/session side effects; an existing-CA-only import scenario must be tested and documented rather than promised to be dependency-free. [P1][P2][A1][A2][L2]

## Current repository evidence

| Location | Observed behavior | Consequence |
| --- | --- | --- |
| `ADCSGoat.psd1`, lines 12, 15, 21 | `PowerShellVersion='5.1'`; `RequiredModules` and `ExternalModuleDependencies` contain only Utility, Management, Security | Neither requested Gallery package is currently a direct installation dependency. [R2] |
| `Build/Build-Module.ps1`, lines 78–86 | Built-ins use `-Type ExternalModule`; PSCertutil, AutomatedLab and PSFramework are skipped, with the latter two called “soft runtime dependencies” | Source-only changes are insufficient; build declarations must change too. [R3][B1] |
| `Build/Build-Module.ps1`, lines 30–43 | Missing publisher installation uses `-MaximumVersion 2.0.27`, but an already available publisher is imported by name without a version argument | The script has an installation ceiling, not an enforced exact tool version. Record the actually selected build-tool version in later evidence; these findings inspect 2.0.27, not today's rewritten publisher API. [R3][B1] |
| `Build/Build-Module.ps1`, lines 131, 139–159 | Imports required modules/self; creates Packed and Unpacked artifacts; then invokes the post-build hook | New requirements also affect build-host imports. Packed output is created before post-build vendoring. [R3][R4][B1] |
| `Build/Invoke-AGPostBuildPublish.ps1`, lines 69–99, 158–167 | Saves PSCertutil 0.0.3 under `Modules`; patches `NestedModules`; publishes using `Publish-Module -Path` from Unpacked | Preserve this vendor/publish path; dependencies must remain in that final manifest after the patch. [R4] |
| `Public/Deploy-AGInfrastructure.ps1`, lines 9–15, 146–190 | PSFramework validation attributes/configuration/UI commands, AutomatedLab commands, and Hyper-V commands; DC/CA/PAW topology | These are real runtime dependencies. This dependency decision does not change the topology, deployment prerequisites, or VM resource prompts. [R5] |

The apparent `#requires ... -Version 7` is inside a block comment in `Deploy-AGInfrastructure.ps1`, lines 19–21. It is not an active requirement and is not evidence for AutomatedLab version 7 or a PowerShell 7 minimum. [R5]

## Standard package and import semantics

### `RequiredModules`

- PowerShell treats these as modules required in global session state. It imports unloaded requirements before importing the requesting module; if unavailable, import fails. This applies to the module as a whole, not only to functions that use the dependency. [P1][P2]
- Microsoft documents that `Install-Module` checks this list and attempts to install missing requirements. PowerShellGet's publishing implementation derives dependencies from the module manifest, resolves them in the publishing repository, and emits NuGet dependency elements. That metadata is how a normal installation obtains dependencies; adding names only to source code or a README does not create package dependencies. [P1][P4][P5][P6]
- `Install-Module` copies packages to an installation location; it does **not** automatically import installed modules. It is therefore distinct from `Import-Module`, which executes dependency initialization. Repository trust, network availability, permissions, command conflicts and normal package-manager prompts can still affect installation; the requirement is automatic dependency resolution, not guaranteed silent installation in every environment. [P3]
- RequiredModules strings have no explicit version floor. A module specification's `ModuleVersion` is a **minimum**; `RequiredVersion` is an exact requirement. PowerShellGet also processes `MaximumVersion` when supplied in a module specification. These are different from ADCSGoat's own `PowerShellVersion` engine minimum. [P1][P2][P5]
- AutomatedLab already requires PSFramework transitively, but direct PSFramework declaration is still appropriate: ADCSGoat itself uses PSFramework attributes and commands, and the requested outcome names both packages. [R1][R5][A1]

### `ExternalModuleDependencies`: important documentation discrepancy

The current `New-ModuleManifest` documentation says this list is documentary, not enforced by PowerShell, and “not used” by PowerShellGet/PSResourceGet/the Gallery. Do not generalize that sentence into this repository's PowerShellGet publishing workflow: the **PowerShellGet v2 implementation explicitly reads `PrivateData.PSData.ExternalModuleDependencies` and skips matching required module names when constructing package dependencies**. The source owns the precise v2 behavior. [P1][P5][P7]

Consequently:

1. Keeping built-in Microsoft modules in both `RequiredModules` and the external list retains their import declarations but prevents PowerShellGet v2 from requiring nonexistent Gallery packages for built-ins. This also matches PSPublishModule's own published manifest/package dependency list. [R2][B1][B2][P5][P7]
2. Putting AutomatedLab or PSFramework in the external list would tell this publishing path to omit them from package dependencies, defeating standard installation even if they also appear in `RequiredModules`. Neither belongs there. [P5][P7]
3. `ExternalModuleDependencies` alone is not a runtime import mechanism and is not a substitute for `RequiredModules`. The present built-in convention is deliberately preserved, not renamed or expanded. [P1][R2]

PowerShellGet v2 also considers nested modules outside the package as possible dependencies, but excludes nested modules whose files are present beneath the package's module base. This supports leaving PSCertutil as the existing packaged nested module rather than adding it as a Gallery RequiredModules entry. [P4][R4]

## PSPublishModule 2.0.27 behavior and exact cutover

### Version-specific source findings

The published 2.0.27 package's `.psm1` contains the legacy PowerShell functions, not the newer C# configuration API currently in the upstream tree. Inspection was against the versioned package; historical linked source provides readable corroboration for the relevant legacy functions. Do **not** copy newer documentation's `-MinimumVersion` parameter into a 2.0.27 build: this package's `New-ConfigurationModule` accepts `-Type`, `-Name`, `-Version`, `-RequiredVersion`, and `-Guid`. [B1][B3]

Observed in the 2.0.27 `.psm1`:

- `New-ConfigurationModule`, lines 16986–17028: name-only configuration becomes a plain string. `-Version` maps to `ModuleVersion`; `-RequiredVersion` maps to `RequiredVersion`; they cannot both be supplied. `Latest`/`Auto` version resolution uses the locally available module, not an independently demonstrated compatibility floor. [B1][B3][B4]
- `New-PrepareStructure`, lines 5845–5853 and 5992–6002: source-manifest loading clears `RequiredModules`, then `RequiredModule` settings rebuild that list; `ExternalModule` settings populate the external list. This is why editing only `ADCSGoat.psd1` is not sufficient. [B1][B5]
- `New-PersonalManifest`, lines 5745–5780: writes external entries to `PrivateData.PSData.ExternalModuleDependencies` **and appends them to `RequiredModules`**. Thus the existing external built-in block should remain; adding required declarations yields the desired five-name import list without adding two Gallery dependencies to the external list. [B1][B6]
- `New-ConfigurationModuleSkip`/`Approve-RequiredModules`: skip configuration suppresses analyzer/build failures for modules not otherwise declared. It is not a Gallery dependency declaration. Remove the stale soft-dependency exceptions instead of treating them as package configuration. [B1][B7]
- `Start-ImportingModules`, lines 7766–7780: `-ImportRequiredModules` explicitly imports the declared requirements. The already-existing build step therefore needs an isolated build host with the dependency graph available. Do not bolt on an ADCSGoat runtime installer. [B1][R3]
- `New-ConfigurationArtefact`, lines 15163–15164: copying required modules into an artifact is separately opt-in through `-AddRequiredModules`/`-RequiredModules`. Current artifact calls do not opt in. Keep this separation: install AutomatedLab and PSFramework as packages rather than copying their trees into ADCSGoat. [B1][R3]

**Constraint pitfall:** with the existing external-module list, 2.0.27's minimal manifest writer reconstructs module-specification hashtables with `ModuleName`, `ModuleVersion`, and `Guid`, dropping `RequiredVersion`; its required-module import helper does not honor an exact `RequiredVersion` either. The configuration function accepting that parameter is not proof that the final artifact retains/enforces it. If future compatibility evidence justifies exact pins or maximum bounds, first plan a version-specific builder correction or a deliberate final-manifest update and prove preservation. No such unrelated tool upgrade or constraint is proposed here. [B1][B6]

### Source-manifest target

Retain existing built-in declarations; append the two packages to the top-level import requirements:

```powershell
RequiredModules = @(
    'Microsoft.PowerShell.Utility'
    'Microsoft.PowerShell.Management'
    'Microsoft.PowerShell.Security'
    'AutomatedLab'
    'PSFramework'
)

# Inside the existing PrivateData.PSData:
ExternalModuleDependencies = @(
    'Microsoft.PowerShell.Utility'
    'Microsoft.PowerShell.Management'
    'Microsoft.PowerShell.Security'
)
```

Ordering above is illustrative; equality of the intended dependency sets is the artifact acceptance criterion. Preserve `PowerShellVersion='5.1'` and current edition declarations unless separate compatibility evidence warrants a deliberate support change. [R2][P1][A1][F1]

### Build-configuration target

Leave the current `New-ConfigurationModule -Type ExternalModule` three-built-in block intact. Add:

```powershell
New-ConfigurationModule -Type RequiredModule -Name 'AutomatedLab', 'PSFramework'

# PSCertutil is intentionally vendored by Invoke-AGPostBuildPublish.
New-ConfigurationModuleSkip -IgnoreModuleName 'PSCertutil'
```

Replace the current three-name skip call with that one-name call, and replace its obsolete “soft runtime dependencies” comment with the vendor-only explanation. Do not use `ApprovedModule` (function integration), `ExternalModule`, `-Version Latest`, or artifact dependency-copy options for these two modules. No extra PSCertutil installation-dependency declaration is needed. [R3][R4][B1][B3]

### Generated and published artifact contract

1. Rebuild rather than hand-patching stale artifacts. Source, generated build manifest, Unpacked manifest, any distributed Packed manifest, and the eventual installed ADCSGoat manifest must retain the same five required module names and exactly the existing three external names. AutomatedLab and PSFramework must remain outside the external list. [R3][B1][P5]
2. Preserve the existing PSCertutil 0.0.3 copy and relative nested entry `Modules\PSCertutil\0.0.3\PSCertutil.psm1`, plus template/help-file copying. The final Unpacked manifest must retain the new dependency declarations after `Update-ModuleManifest -NestedModules`; this is an acceptance check, not an observed result from a build in this research. [R4]
3. Continue publishing from the **post-vendoring Unpacked path** via the existing hook. Do not enable PSPublishModule's ordinary by-name publishing; the repository intentionally avoids that because it could select the pre-vendoring module from `PSModulePath`. [R3][R4]
4. The produced `.nupkg`/`.nuspec` must have direct package dependency IDs `AutomatedLab` and `PSFramework`, not the built-ins or vendored PSCertutil. Inspect metadata instead of assuming the source manifest survived packaging. [P4][P5][P6]
5. **Existing Packed timing caveat:** Packed output is generated before this post-build hook patches/copies the Unpacked tree. [INFERENCE] It cannot be assumed to be the final publish-equivalent package merely because its RequiredModules metadata matches. If Packed is distributed as a complete module, regenerate it from the finalized vendored Unpacked tree (or move packing after finalization in the implementation plan) and check its nested payload. This is a packaging acceptance detail, not a proposal to change PSCertutil's vendor strategy. [R3][R4][B1]

## Supported PowerShell declarations and existing-CA import implications

| Dependency evidence | PowerShell support declarations | Concrete implications |
| --- | --- | --- |
| AutomatedLab 5.61.0 released manifest | Minimum `5.1`; `CompatiblePSEditions = 'Core','Desktop'`; Desktop .NET/CLR manifest fields `4.0` | Supports retaining ADCSGoat's manifest minimum at the declaration level; not proof of every host/PowerShell 7/AD CS combination. [A1][L1] |
| AutomatedLab 5.61.0 `RequiredModules` | AutomatedLabCore; AutomatedLab.Common >=2.3.37; AutomatedLab.Recipe; AutomatedLab.Ships; AutomatedLabDefinition; AutomatedLabNotifications; AutomatedLabTest; AutomatedLabUnattended; AutomatedLabWorker; PSLog; PSFileTransfer; Pester; powershell-yaml; PSFramework; SHiPS | A substantial transitive installation **and import** graph, not just two directories. AL's own unversioned submodule declarations must be accounted for by the resolver; don't replace them with handpicked ADCSGoat vendoring. [A1][P1][P4] |
| PSFramework 1.14.457 released metadata/source manifest | Minimum `3.0`; Gallery advertises Core/Desktop; no package dependencies | Doesn't force an increase above ADCSGoat's 5.1 minimum. Initialization loads its DLL and type infrastructure; ADCSGoat's `PsfValidatePattern` attribute is a registered PSFramework type alias. [F1][F2][L3][L4] |

The parent observed the two versions through `Get-Module -ListAvailable`; local manifests corroborate these declarations. That command did not import modules or prove CA/deployment compatibility. [L1][L3]

On an existing-CA-only host, the dependency cutover has these consequences:

- Import requires the complete installed dependency graph before any ADCSGoat CA function can be used. Missing packages make the entire module import fail; offline copying of only ADCSGoat is insufficient unless its requirements are also staged. Installing package files is not a Windows role/feature installer, so this declaration does not itself satisfy Hyper-V or lab media prerequisites. [P1][P3][R5]
- AutomatedLabCore 5.61.0's top-level initialization loads edition-specific `AutomatedLab.dll`; on Windows Core edition it attempts a DISM-module import; it conditionally creates a `Labs:` SHiPS drive, sets the Azure warning-suppression environment variable, initializes PSFramework settings, and makes a GitHub latest-release request unless its disable-version-check configuration is set. These are import-time behavior even without invoking `Deploy-AGInfrastructure`. [A2][L2]
- It also attempts to create/copy product-key assets under its configured application-data root, normally `C:\ProgramData\AutomatedLab` on Windows, and exports a custom product-key store if missing. [INFERENCE] A fresh non-administrator existing-CA-only import can encounter ProgramData permission/initialization issues; actual failure/success requires the proposed isolated check. Do not label import harmless or guaranteed non-admin-compatible. [A2][L2]
- PSFramework 1.14.457's compiled import loads `bin\PSFramework.dll` for PowerShell >=5 and appends type data, then runs its framework initialization. The relevant attribute alias is `PSFramework.Validation.PsfValidatePatternAttribute`. [F2][L3][L4]
- Requiring AutomatedLab doesn't mean ADCSGoat invokes `Install-Lab` on import: the inspected deployment call is inside `Deploy-AGInfrastructure`. Nevertheless, dependency initialization is real execution, and this research does not claim a complete audit of all transitive import effects. [R5][A1][A2]

## Later isolated proof plan — not executed

All installation/import/publication steps below belong in an explicitly approved disposable Windows VM/runner, **not this workstation or an existing user's CA**. A fresh `-NoProfile` process alone is not filesystem/account isolation; dependency initialization can write ProgramData and use the network. Use separate disposable profiles/machines and record exact PowerShell, PowerShellGet, PSPublishModule, and resolved dependency versions. [P3][A2][R3]

### 1. Manifest/artifact inspection

Read manifests as data and compare required/external sets at the source, build output, finalized Unpacked, extracted Packed (if distributed), and package-extracted stages. Assert both Gallery dependencies are present, neither is external, built-ins are unchanged, and PSCertutil's 0.0.3 nested file exists. Inspect `.nuspec` dependency IDs/ranges too. These checks establish metadata preservation, not import compatibility. [P4][P5][P6][R4]

### 2. Standard package-resolution smoke

After a candidate build exists, use a disposable private/file-share PowerShellGet repository containing the candidate ADCSGoat package **and the full real dependency closure**. PowerShellGet v2 resolves publishing requirements in the target repository; simply pointing ADCSGoat at an empty local feed does not prove Gallery dependencies resolve. Follow Microsoft's recommendation to test publishing with a private/local repository rather than using PSGallery as a test target. Any temporary private publication would require a later approved execution step. [P5][P8]

In a fresh disposable account with AutomatedLab/PSFramework absent, run the normal `Install-Module ADCSGoat -Repository <isolated repository> -Scope CurrentUser` flow and inventory installed modules/versions. The caller must not explicitly preinstall the two requirements or their closure. Assert both direct dependencies and the transitive graph are installed, and that built-ins/PSCertutil are not downloaded as separate ADCSGoat requirements. Keep normal prompts/real errors visible. `Save-Module` into a disposable staging directory is a complementary resolution check, not a replacement for the requested standard installation proof. [P1][P3][P4][P5]

Prove a missing/incompatible dependency in that isolated repository causes a meaningful resolution failure; do not bypass dependencies or substitute mocks. A later Gallery metadata query can check the released package's dependency IDs without installing anything, but cannot prove import behavior. [P5][P6]

### 3. Import-only compatibility smoke

In clean Windows PowerShell 5.1 and a representative supported PowerShell 7 host, import the **manifest** (not the `.psm1` directly) from the installed candidate with terminating errors captured. Confirm ADCSGoat exports its ordinary CA commands and `Deploy-AGInfrastructure`, that AutomatedLab/PSFramework are actually loaded, and that the deployment command's parameter metadata resolves PSFramework validation attributes. Direct `.psm1` import can bypass manifest dependencies and would not prove the contract. [P1][R2][R5][F2]

Include a disposable existing-CA-only host/profile with no lab/Hyper-V deployment performed, both a fresh non-admin import and an admin import, and an offline-after-install import. Record warnings, assemblies/types, dependency versions, network attempts, ProgramData writes, and any errors; do not call destructive CA/lab functions merely to prove import. The 5.1/Core edition declarations are evidence to choose these checks, not a passed support matrix. An isolated missing-dependency import should fail clearly. [P1][A1][A2][F1][L2]

These checks prove packaging/resolution/loadability. They do **not** prove Windows Server 2025 VM creation, resource prompt behavior, or operational deployment; those belong to the parent planning map's other tickets. [R1][R5]

## Evidence limits

No package-resolution, import, build, or deployment result is asserted. No new compatibility floor/ceiling was established. The newer upstream publisher documentation must not be substituted for 2.0.27 behavior. Microsoft's current external-dependency description conflicts with PowerShellGet v2 source; the v2 exclusion source is the decisive evidence for this repository's publication path. Existing-CA import side effects are grounded in actual 5.61.0 source reads; their outcome on each support host remains unverified. [B1][P1][P5][L2]

## Primary sources and repository references

- [R1 — Assigned installation-dependency ticket](../issues/03-installation-dependencies.md).
- [R2 — Source manifest](../../../ADCSGoat.psd1), lines 6, 12–21.
- [R3 — Module build configuration](../../../Build/Build-Module.ps1), lines 30–43, 78–86, 131–159.
- [R4 — Post-build vendor/publish hook](../../../Build/Invoke-AGPostBuildPublish.ps1), lines 69–99, 105–137, 158–167.
- [R5 — Infrastructure deployment function](../../../Public/Deploy-AGInfrastructure.ps1), lines 9–21, 129, 146–190.
- [P1 — Microsoft: New-ModuleManifest, RequiredModules and ExternalModuleDependencies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/new-modulemanifest?view=powershell-7.6#-requiredmodules).
- [P2 — Microsoft: Gallery publishing guidelines, Manage Dependencies](https://learn.microsoft.com/en-us/powershell/gallery/concepts/publishing-guidelines#manage-dependencies).
- [P3 — Microsoft: PowerShellGet 2.x Install-Module](https://learn.microsoft.com/en-us/powershell/module/powershellget/install-module?view=powershellget-2.x).
- [P4 — PowerShellGet v2: Get-ModuleDependencies source](https://github.com/PowerShell/PowerShellGetv2/blob/master/src/PowerShellGet/private/functions/Get-ModuleDependencies.ps1).
- [P5 — PowerShellGet v2: ValidateAndGet-RequiredModuleDetails source](https://github.com/PowerShell/PowerShellGetv2/blob/master/src/PowerShellGet/private/functions/ValidateAndGet-RequiredModuleDetails.ps1), especially the ExternalModuleDependencies exclusion and same-repository resolution.
- [P6 — PowerShellGet v2: New-NuspecFile source](https://github.com/PowerShell/PowerShellGetv2/blob/master/src/PowerShellGet/private/functions/New-NuspecFile.ps1), dependency elements.
- [P7 — PowerShellGet v2: Get-ExternalModuleDependencies source](https://github.com/PowerShell/PowerShellGetv2/blob/master/src/PowerShellGet/private/functions/Get-ExternalModuleDependencies.ps1).
- [P8 — Microsoft: Test using a local repository](https://learn.microsoft.com/en-us/powershell/gallery/concepts/publishing-guidelines#test-using-a-local-repository).
- [B1 — Versioned PSPublishModule 2.0.27 package](https://www.powershellgallery.com/packages/PSPublishModule/2.0.27), [raw package API](https://www.powershellgallery.com/api/v2/package/PSPublishModule/2.0.27). The versioned `.psm1` supplied the exact source/line observations above; it was decompressed in memory and never installed/imported/saved to a module path.
- [B2 — PSPublishModule 2.0.27 published manifest](https://www.powershellgallery.com/packages/PSPublishModule/2.0.27/Content/PSPublishModule.psd1).
- [B3 — Legacy New-ConfigurationModule readable source](https://github.com/EvotecIT/PSPublishModule/blob/18a17d67cd8f5cfb0945ece7115ad017cc69fd4e/Public/New-ConfigurationModule.ps1); corroborates the versioned package's PowerShell implementation, not the newer C# API.
- [B4 — Legacy Convert-RequiredModules source](https://github.com/EvotecIT/PSPublishModule/blob/b66d225a23dddf0626646a47c1abe20dbf03454b/Module-PSPublishModule/Private/Convert-RequiredModules.ps1).
- [B5 — Legacy New-PrepareStructure source](https://github.com/EvotecIT/PSPublishModule/blob/b66d225a23dddf0626646a47c1abe20dbf03454b/Module-PSPublishModule/Private/New-PrepareStructure.ps1).
- [B6 — Legacy New-PersonalManifest source](https://github.com/EvotecIT/PSPublishModule/blob/b66d225a23dddf0626646a47c1abe20dbf03454b/Module-PSPublishModule/Private/New-PersonalManifest.ps1); the versioned 2.0.27 package was inspected directly for the retained/dropped module-specification fields.
- [B7 — Legacy New-ConfigurationModuleSkip source](https://github.com/EvotecIT/PSPublishModule/blob/b66d225a23dddf0626646a47c1abe20dbf03454b/Module-PSPublishModule/Public/New-ConfigurationModuleSkip.ps1).
- [A1 — AutomatedLab 5.61.0 Gallery metadata](https://www.powershellgallery.com/packages/AutomatedLab/5.61.0) and [released manifest](https://www.powershellgallery.com/packages/AutomatedLab/5.61.0/Content/AutomatedLab.psd1).
- [A2 — AutomatedLabCore initialization source](https://github.com/AutomatedLab/AutomatedLab/blob/develop/AutomatedLabCore/internal/scripts/Initialization.ps1), lines 1–74 and 1112–1143 at retrieval; cross-checked against locally installed 5.61.0 compiled source, not used to infer a future release result.
- [F1 — PSFramework 1.14.457 Gallery metadata](https://www.powershellgallery.com/packages/PSFramework/1.14.457) and [source manifest](https://github.com/PowershellFrameworkCollective/psframework/blob/development/PSFramework/PSFramework.psd1).
- [F2 — PSFramework initialization source](https://github.com/PowershellFrameworkCollective/psframework/blob/development/PSFramework/PSFramework.psm1) and [attribute type-alias source](https://github.com/PowershellFrameworkCollective/psframework/blob/development/PSFramework/bin/type-aliases.ps1); the actual local compiled 1.14.457 import preamble was also read.
- [L1 — Installed AutomatedLab 5.61.0 manifest](file:///C:/Program%20Files/WindowsPowerShell/Modules/AutomatedLab/5.61.0/AutomatedLab.psd1), lines 15–68. Local availability additionally reported by the parent; no import was performed.
- [L2 — Installed AutomatedLabCore 5.61.0 source](file:///C:/Program%20Files/WindowsPowerShell/Modules/AutomatedLabCore/5.61.0/AutomatedLabCore.psm1), lines 25019–25089 and 26132–26165.
- [L3 — Installed PSFramework 1.14.457 manifest](file:///C:/Program%20Files/WindowsPowerShell/Modules/PSFramework/1.14.457/PSFramework.psd1), lines 7, 25; [compiled module source](file:///C:/Program%20Files/WindowsPowerShell/Modules/PSFramework/1.14.457/PSFramework.psm1), lines 116–137.
- [L4 — Installed PSFramework attribute aliases](file:///C:/Program%20Files/WindowsPowerShell/Modules/PSFramework/1.14.457/bin/type-aliases.ps1), line 38.
