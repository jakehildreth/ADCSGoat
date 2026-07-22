# 12 — Remove legacy psake files and verify end-to-end

**What to build:** Delete the legacy psake/PowerShellBuild files, then run a full local build and verify that the produced artefact loads, passes Pester tests, and can load the certificate-template XML files at runtime.

**Blocked by:** 10 — Create PSPublishModule build scripts, 11 — Update CI workflow for PSPublishModule

**Status:** ready-for-agent

- [ ] `psakeFile.ps1`, `build.ps1`, and `requirements.psd1` are removed.
- [ ] `Build/Build-Module.ps1` runs end-to-end on a clean checkout.
- [ ] `Invoke-Pester -Path ./Tests/` passes against the source code.
- [ ] Importing the built `Artefacts/Unpacked/ADCSGoat/ADCSGoat.psd1` succeeds and exports the expected commands.
- [ ] `Install-ADCSGoat` can resolve `Private/Template/*.xml` from the built artefact (verified by inspection or a targeted smoke test).
- [ ] `Artefacts/` is added to `.gitignore` if not already present.
