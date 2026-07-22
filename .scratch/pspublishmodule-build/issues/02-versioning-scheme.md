## Question

Should ADCSGoat switch from SemVer (`0.4.0`) to CalVer (`yyyy.M.dHHmm`) like Locksmith2 and Stepper?

The current manifest uses `ModuleVersion = '0.4.0'` and `Prerelease = 'prerelease'`. The reference repos use date-based CalVer. This decision affects the manifest, `Build-Module.ps1`, and the CI version-bump logic.

## Answer

Switch to CalVer (`yyyy.M.dHHmm`) for `ModuleVersion`, with optional prerelease tags passed via `Build-Module.ps1`'s `-Prerelease` parameter. This matches Locksmith2/Stepper and removes the need for manual version bumps or the `BuildHelpers` version-bump check in CI.

Type: grilling
Status: resolved
