# 10 — Create PSPublishModule build scripts

**What to build:** Add `Build/Build-Module.ps1` and `Build/Invoke-AGPostBuildPublish.ps1` so ADCSGoat builds with PSPublishModule 2.0.27, uses CalVer, vendors PSCertutil into the artefact, skips AutomatedLab/PSFramework during analysis, and copies the runtime-critical XML template files into the built module.

**Blocked by:** 09 — Rearrange repo layout for PSPublishModule

**Status:** ready-for-agent

- [ ] Running `Build/Build-Module.ps1` completes without errors and produces `Artefacts/Unpacked/ADCSGoat/` and `Artefacts/Packed/`.
- [ ] The built `ADCSGoat.psd1` imports successfully and exports the expected public functions.
- [ ] The Unpacked artefact contains a `Modules/PSCertutil/<version>/` directory with a patched `NestedModules` entry.
- [ ] The Unpacked artefact contains `Private/Template/*.xml` so `Install-ADCSGoat` can load them.
- [ ] `AutomatedLab` and `PSFramework` are not listed as required modules in the built manifest.
