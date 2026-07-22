## Destination

ADCSGoat builds and publishes with PSPublishModule 2.0.27 instead of psake/PowerShellBuild, adopting the directory structure and `Build-Module.ps1` pattern used by Locksmith2 and Stepper.

## Notes

- Reference repos: `~/Code/PowerShell/Locksmith2` and `~/Code/PowerShell/Stepper`
- Current state: `psakeFile.ps1`, `build.ps1`, `requirements.psd1`, module under `./ADCSGoat/`
- Skills to consult while working tickets: `code-review`, `domain-modeling`, `grilling`, `prototype`, `research`, `implement`

## Decisions so far

- [Directory layout: move module files to repo root](issues/01-directory-layout.md) — aligns ADCSGoat with the Locksmith2/Stepper root-level module layout.
- [Versioning scheme: switch to CalVer](issues/02-versioning-scheme.md) — every build gets a unique `yyyy.M.dHHmm` version; prerelease tags passed at build time.
- [Manifest ownership: PSPublishModule owns the manifest](issues/03-manifest-ownership.md) — metadata and dependencies are declared in `Build-Module.ps1`; root `.psd1` is build output.
- [Test directory: rename to `./Tests/`](issues/04-test-directory.md) — matches reference repo convention; `ScriptAnalyzerSettings.psd1` moves inside.
- [Docs directory: rename to `./Docs/`](issues/05-docs-directory.md) — matches reference repo convention; existing `en-US/` help files preserved and doc generation disabled.
- [Dependencies & templates: vendor PSCertutil, skip AutomatedLab/PSFramework, copy template XMLs post-build](issues/06-dependencies-and-templates.md) — detailed recommendations in [`research/06-findings.md`](research/06-findings.md).
- [Design `Build/Build-Module.ps1`](issues/07-design-build-module-ps1.md) — CalVer manifest, skip vendored/soft deps, no merge until template path is fixed, post-build vendoring script.
- [Update GitHub Actions workflow](issues/08-update-ci-workflow.md) — `windows-latest`, install PSPublishModule + PSCertutil, run Pester, build/publish via `Build-Module.ps1`, emit version.

## Not yet specified

<!-- all decisions are now locked; implementation is the next step -->

## Out of scope

- Changing module functionality or cmdlet implementations
- Rewriting Pester tests from scratch
- Switching away from GitHub Actions / PSGallery
