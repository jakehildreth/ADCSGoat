# 09 — Module scaffold and cmdlets

**What to build:** Create the `ADCSGoat` PowerShell module structure so students can install the module and open the embedded site. This ticket makes `Start-ADCSGoatSite` and `Get-ADCSGoatSitePath` work end-to-end, even before any HTML content exists.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `ADCSGoat.psd1` module manifest exists with appropriate metadata, version, and exported cmdlets.
- [ ] `ADCSGoat.psm1` dot-sources functions from `Public/`.
- [ ] `Public/Start-ADCSGoatSite.ps1` resolves `Assets/index.html` relative to the module and opens it in the default browser.
- [ ] `Public/Get-ADCSGoatSitePath.ps1` returns the full path to the `Assets/` folder.
- [ ] Pester tests verify both cmdlets resolve paths correctly and that `Start-ADCSGoatSite` invokes the browser.
