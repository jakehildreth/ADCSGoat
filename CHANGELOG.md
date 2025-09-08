# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

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

