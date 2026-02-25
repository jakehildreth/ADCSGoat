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
  - [Semantic Versioning](http://semver.org/)
  - [Conventional Commits](https://www.conventionalcommits.org/)
  - [git-cliff](https://git-cliff.org)
