# Pester tests vs artifact layout

Type: grilling
Status: resolved
Blocked by: 03, 04

## Question

Update the Pester tests to target the current artifact layout, or restore the documented output contract?

Current tests expect `Output/ADCSGoat/<version>/ADCSGoat.psd1`, which the build did not produce. Blocked until the canonical artifact layout (03) and version stamping (04) are decided — the tests encode whichever layout wins.

## Answer

**Update the tests to the real artifact layout (option A).** The `Output/<Module>/<version>/` contract died with the PSStucco/BuildHelpers build system in the PSPublishModule migration (`7b8c203`) — it is not restorable and shouldn't be.

Findings that shaped this:

- The `BH*` env vars (`BHProjectName`, `BHProjectPath`, `BHPSModuleManifest`) come from BuildHelpers, scaffolding from the PSStucco template the repo started from. Nothing in the repo sets them anymore; `Manifest.tests.ps1` and `Help.tests.ps1` fail before their first assertion. `Meta.tests.ps1` already falls back to `$PSScriptRoot`.
- The canonical artifact is `Artefacts/Unpacked/ADCSGoat/ADCSGoat.psd1` (ticket 03), with no version subdirectory.

The rewrite, when executed:

1. Both test files derive paths from `$PSScriptRoot` → `Artefacts/Unpacked/ADCSGoat/ADCSGoat.psd1`; BuildHelpers env vars deleted. Version is read from the artifact manifest, not a directory name.
2. The "Changelog and manifest versions are the same" assertion is **deleted** from the always-on suite. Under ticket 01 the changelog regenerates at release time, so this only holds at release — and it's already enforced there by ticket 04's post-build assertion and 11's publish gate. The already-`-Skip`ped Git tagging Describe block stays skipped.
3. **Build-required guard:** `Manifest.tests.ps1` and `Help.tests.ps1` test the built artifact, so a fresh clone without a build has nothing to import (true under the old `Output/` contract too). If `Artefacts/Unpacked/ADCSGoat/ADCSGoat.psd1` is missing, the Describe blocks skip with a clear reason ("run `Build/Build-Module.ps1` first") instead of failing — a fresh-clone `Invoke-Pester` runs green. `Meta.tests.ps1` is unaffected; it lints source and runs standalone.
