## [Unreleased]

### Added

- Offer editable startup memory and CPU suggestions for DC, CA, and PAW, with per-VM overrides and a noninteractive deployment mode.
- Cover invalid resource settings and noninteractive deployment conflicts with public-command regression tests.
- Add deploy entrypoint (`Deploy-ADCSGoat`) for the four replacement scenarios: selected-CA contract, preflight report, and state file — demoable on its own with zero AD writes
- Add selected-CA resolution (`Get-AGEnrollmentService`): optional `-CAName`, single-CA autodetect, multi-CA/invalid-name errors before any AD write
- Add preflight report (`Test-AGDeployPreflight`): hard prerequisites (selected CA resolves, Web Server name-flag bit 0x1, Domain Users can enroll in User) abort with prerequisite errors naming check + remediation
- Add machine-readable deploy state file (`New-AGDeployState`/`Save-AGDeployState`/`Read-AGDeployState`): captures selected CA identity, pre-change certificateTemplates list, and pre-change nTSecurityDescriptor (SDDL + binary) before any AD write; per-clone records appended as scenarios deploy
- Add ESC1 scenario deploy (`Deploy-AGEsc1`): clones Web Server to 'Copy of Web Server', appends Client Authentication to both EKU attributes (preserving Server Auth), grants Domain Users Read + Enroll on the copied DACL, publishes on the selected CA, and records the clone in the state file; Web Server source left byte-identical
- Add ESC4 scenario deploy (`Deploy-AGEsc4`): clones Web Server to 'Test SSL' with zero attribute overrides, grants Domain Users Full Control on the copied DACL, publishes on the selected CA, and records the clone in the state file; Web Server source left byte-identical
- Add shared scenario pipeline (`Invoke-AGTemplateScenario`): the clone -> recipe -> rights -> publish -> record-state sequence every scenario deploy rides; scenario functions supply only the recipe and rights scriptblocks
- Add ESC3 chain scenario deploy (`Deploy-AGEsc3Chain`): clones SubCA to 'VMware 6.x' with no EKU override, grants Authenticated Users Read + Enroll, publishes VMware 6.x and the built-in User template (ACL unchanged) on the selected CA, and records the clone in the state file; SubCA and User left unchanged, never touches NTAuthCertificates
- Add ESC4+ESC5 chain scenario deploy (`Deploy-AGEsc5Chain`): clones Workstation Authentication to 'Copy of Workstation' (zero attribute overrides, Domain Users Full Control) left deliberately unpublished, and grants Authenticated Users Full Control on the selected CA's pKIEnrollmentService object (never the CA host/service security descriptor). Redeploy enforces pristine state by stripping an exercise-published 'Copy of Workstation' cn from certificateTemplates
- Add CA-object ACL setter (`Set-AGEnrollmentServiceAce`) with idempotent dedupe predicate (`Test-AGAccessRulePresent`); scenario pipeline gains `-SkipPublish` for the unpublished-chain design
- Add state-driven teardown (`Invoke-AGDeployTeardown`): removes recorded clone cns and restores the CA's certificateTemplates to its pre-change member set, deletes clone and companion OID objects, then restores the Enrollment Services security descriptor byte-for-byte LAST; any failure in the earlier steps aborts before the ACL restore and leaves the grant in place

### Removed

- Retire the legacy six-scenario internals (`New-AGBlankTemplateObject`, `Set-AGTemplateProperty`, `Set-AGTemplateAce`, `Publish-AGCertifcateTemplate`) and the `Private/Template` XML/JSON property snapshots; `Install-ADCSGoat` now orchestrates the four scenario deploys and `Uninstall-ADCSGoat` drives the state-file teardown, with no legacy detection

### Changed

- Default all lab VMs to Windows Server 2022 Standard Desktop Experience.
- Use a 2 GB dynamic-memory minimum, 4 GB startup suggestion, and maximum memory of at least 4 GB or the selected startup value.
- Make AutomatedLab and PSFramework deployment-only dependencies instead of ADCSGoat installation requirements; importing ADCSGoat inside the VMs no longer loads them.
- Replace obsolete static metadata/help test scaffolding with behavior checks at the deployment boundary.

### Fixed

- Return control to the caller when deployment is declined instead of ending the PowerShell session.
- Install missing AutomatedLab dependencies from PSGallery in CurrentUser scope, respecting dependency version constraints before infrastructure deployment; preserve existing compatible modules and report installation or import failures.

## [0.4.1] - 2026-02-25

### 🐛 Bug Fixes

- Format EnrollGUID assignment
- Upate cached modules and update required version for PSCertutil
- Update ScriptAnalysisSettings for improved linting rules

### 🚜 Refactor

- Improve variable naming, remove AD PS module dependency
- Bring Set-AGTemplateAce.ps1 inline with existing style
- AccessRule creation with regex switch

### ⚙️ Miscellaneous Tasks

- Remove unused dependencies 'AutomatedLab' and 'PSFramework' from requirements
- *(docs)* Update README, LICENSE, and manifest to align with standards
- Update changelog for version 0.4.0 and add PSRepositoryApiKey property
- Updated variable name to match content
- Fix else and finally formatting because OTBS
- Cuddled catch is 🥰
- Nitpix
## [0.4.0] - 2026-02-21

### ⚙️ Miscellaneous Tasks

- Add PSRepositoryApiKey to properties for publishing
## [unreleased]

### ⚙️ Miscellaneous Tasks

- Remove unused dependencies 'AutomatedLab' and 'PSFramework' from requirements
## [unreleased]

### 🐛 Bug Fixes

- Change prefix of commands pulled from PSCertutil

### ⚙️ Miscellaneous Tasks

- Moving template files into default directories so they are published in the module that goes to PSGallery
- Update template properties path to use script root for consistency
- Add git-cliff configuration for changelog generation

## [0.3.1]

Trying a thing.

## [0.3.0]

### Added
* `Install-ADCSGoat` - creates 6 vulnerable templates and configures CAs with 2 misconfiguration
* `Uninstall-ADCSGoat` - removes all vulnerabilities created by `Install-ADCSGoat`

## [0.2.2]

### Changed
Module name is now ADCSGoat

## [0.2.1]

### Added

Prelease version to see how to create a prerelease version.

## [0.2.0]

### Added
* `New-BLLBlankTemplateObject` - pass in a string to create a blank template object named after that string
* `Set-BLLTemplateProperty` - pass in a hashtable containing properly formatted template properties, and they apply to the template you name
* `Set-BLLTemplateAce` - pass in an existing templates name and the type of ACE you want to create, and the ACE is added to the template's DACL

## [0.1.0]

Initial commit. Doesn't do anything. Just learning PSStucco.

# Changelog Meta

All notable changes to this project will be documented in this file.

Using:
  - [Keep a Changelog](http://keepachangelog.com/)
  - [Calendar Versioning](https://calver.org/)
  - [Conventional Commits](https://www.conventionalcommits.org/)
  - [git-cliff](https://git-cliff.org)
