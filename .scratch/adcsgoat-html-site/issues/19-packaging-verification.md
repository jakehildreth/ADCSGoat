# 19 — Packaging verification

**What to build:** Confirm the PowerShell module packages correctly for distribution. The published module contains the site assets and omits build tooling.

**Blocked by:** 09 — Module scaffold and cmdlets, 18 — Accessibility, print, and validation pass

**Status:** ready-for-agent

- [ ] PSPublishModule 2.0.27 builds the module successfully.
- [ ] The produced package includes the `Assets/` folder with all HTML, CSS, JS, fonts, and diagrams.
- [ ] The produced package excludes the `Build/` folder and any `.mmd` source files.
- [ ] Installing the packaged module and running `Start-ADCSGoatSite` opens the site from the installed location.
