# ADCSGoat Release Checklist

Working release target: **2026.8.121930** (replace with the final release version before publishing).

This checklist is for the AD CS talk lab dependency. A release is not ready until every blocking item is verified from a clean artifact and, where applicable, an authorized Hyper-V lab.

## Current baseline

- Repository: `main`, clean before audit, HEAD `7b8c203`.
- Latest repository tag: `0.4.1`.
- Source manifest version: `2026.7.220804`.
- PowerShell Gallery latest observed version: `2026.7.221210`.
- Build dependencies available locally: Pester `5.7.1`, PSPublishModule `2.0.27`, PSCertutil `0.0.3`.

## Blocking release gates

- [ ] Choose and apply one version consistently across source manifest, generated artifact manifest, changelog, Git tag, and Gallery package.

- [ ] Make the build fail when a required vendored dependency cannot be saved. The current build continued after `Save-Module` reported an access error.

- [ ] Make the build clean its artifact directories reliably. PSPublishModule emitted deletion warnings and left a duplicate nested module layout.

- [ ] Ensure the generated artifact contains the exact module version requested by `-CalVer`. The audit requested `2026.8.121930`; the artifact manifest read back `2026.7.220807`.

- [ ] Update the Pester tests to target the current artifact layout, or restore the documented output contract. The current tests expect `Output/ADCSGoat/<version>/ADCSGoat.psd1`, which the build did not produce.

- [ ] Remove stale generated-help placeholders, including `{{ Fill Randomize Description }}`, or regenerate valid help from source comments.

- [ ] Resolve the unused `-Randomize` parameters, either by implementing their behavior or removing the public parameters and documentation.

- [ ] Define and verify uninstall restoration for every CA setting changed by installation. The current ESC5 restoration path is commented out, and the install path does not currently enable the shown ESC5 operation.

- [ ] Add a clean-install artifact check: manifest validity, module import, required command inventory, vendored `PSCertutil`, all template support files, and about-topic help.

- [ ] Run the install/uninstall workflow in the authorized Hyper-V lab and verify both the vulnerable states and post-uninstall state.

- [ ] Run the full Pester suite against the actual release artifact.

- [ ] Publish only after all gates pass; read back the Gallery version and package contents.

## Non-blocking observations

- The source PowerShell files parse successfully on PowerShell 7.6.4: 90 files checked.

- The source manifest passes `Test-ModuleManifest`.

- The repository contains no tracked credential or API-key value; CI references the Gallery key through a GitHub secret.

- `PlatyPS` is not installed locally, so documentation generation was not independently exercised.

## Evidence to capture

- Build command and complete output.

- Artifact manifest and file inventory.

- Pester result.

- Clean import and command inventory.

- Authorized lab install/uninstall transcript with before/after CA and template state.

- Git tag, GitHub release if used, Gallery read-back, and package hash.
