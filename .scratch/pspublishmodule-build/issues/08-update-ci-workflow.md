## Question

How should `.github/workflows/publish.yaml` be rewritten to use `Build/Build-Module.ps1`?

Replace the current psake/PowerShellBuild/BuildHelpers-based workflow with one that installs PSPublishModule 2.0.27, runs tests, and calls `./Build/Build-Module.ps1 -PublishToPSGallery`. This should follow the Locksmith2/Stepper workflow pattern.

## Answer

Approved workflow design for `.github/workflows/publish.yaml`:

- Trigger on push to `main`, filtered to paths that affect the module: `Public/`, `Private/`, `Build/`, `ADCSGoat.psm1`, `ADCSGoat.psd1`, `LICENSE`; plus `workflow_dispatch`
- Single `build-and-publish` job on `windows-latest`
- Install step: Pester, PSScriptAnalyzer, PSPublishModule ≤ 2.0.27, PSCertutil
- Test step: `Invoke-Pester -Path ./Tests/ -PassThru -CI -Output Detailed`; fail build on any failed test
- Build/publish step: `./Build/Build-Module.ps1 -PublishToPSGallery -PSGalleryAPIKey $env:PSGALLERY_API_KEY`
- Version step: read built `ADCSGoat.psd1` and emit `version` output (including prerelease suffix if present)
- The existing `BuildHelpers` version-bump check is removed because CalVer produces a new version on every qualifying push.

Implementation of the workflow file is a separate execution step.

Type: grilling
Status: resolved
