# Build fails on vendored-dep save error

Type: grilling
Status: resolved

## Question

How should the build guarantee failure when a required vendored dependency cannot be saved?

The audit observed the build continuing after `Save-Module` reported an access error. Options to weigh: explicit error handling in `Build/Build-Module.ps1`, post-build verification that the vendored PSCertutil exists in the artifact, or PSPublishModule-native enforcement if it exists.

## Answer

**Targeted hardening (option A).** Three failure holes were found:

1. `Save-Module` runs without `-ErrorAction Stop`, so a non-terminating access error doesn't stop execution.
2. The vendored-folder guard accepts *any* pre-existing version folder (`Sort Name -Desc | Select -First 1`), so a stale folder from a previous build masks a failed save.
3. Every guard is `Write-Error` + `return` — non-terminating — and `Build-Module.ps1` never checks `$Error` or sets an exit code, so failures exit 0 and CI can't see them.

The fix, when executed:

- `-ErrorAction Stop` on `Save-Module` (and other failure-critical cmdlets in `Invoke-AGPostBuildPublish`).
- `throw` instead of `Write-Error`/`return` in post-build guards.
- The vendored-folder guard tests for the *pinned* version folder specifically (`Test-Path (Join-Path $modulesTarget "$depName\$pinned")`), not "any folder".
- `Build-Module.ps1` wraps the build in try/catch and exits non-zero on failure.

Rejected: global `$ErrorActionPreference = 'Stop'` (makes PSPublishModule-internal noise fatal) and a detect-only post-build verification step (ticket 09's clean-install check will serve as that backstop instead).
