# 11 — Update CI workflow for PSPublishModule

**What to build:** Rewrite `.github/workflows/publish.yaml` so that pushes to `main` install PSPublishModule 2.0.27 and PSCertutil, run Pester from `Tests/`, and call `Build/Build-Module.ps1 -PublishToPSGallery` to publish the fully vendored artefact.

**Blocked by:** 10 — Create PSPublishModule build scripts

**Status:** ready-for-agent

- [ ] The workflow triggers on push to `main` when module-relevant paths change.
- [ ] The install step installs Pester, PSScriptAnalyzer, PSPublishModule (maximum version 2.0.27), and PSCertutil.
- [ ] The test step runs Pester from `./Tests/` and fails the job if any test fails.
- [ ] The publish step calls `./Build/Build-Module.ps1 -PublishToPSGallery -PSGalleryAPIKey …`.
- [ ] The BuildHelpers version-bump check and psake bootstrap are removed.
