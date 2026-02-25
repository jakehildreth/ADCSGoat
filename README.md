# ADCSGoat

A tiny module built for a single purpose: building a small and very insecure AD CS lab.

## Overview

ADCSGoat creates vulnerable Active Directory Certificate Services (AD CS) certificate templates and CA misconfigurations in a lab environment. It deploys the following ESC scenarios:

| Scenario | Description |
|----------|-------------|
| ESC1 | Enrollee supplies subject in SAN-enabled template |
| ESC2 | Overly permissive template allows any purpose |
| ESC3 (Condition 1) | Enrollment agent template misconfiguration |
| ESC3 (Condition 2) | Certificate request agent abuse |
| ESC4 | Vulnerable certificate template ACLs |
| ESC6 | EDITF_ATTRIBUTESUBJECTALTNAME2 enabled on CA |
| ESC9 | No security extension on template |
| ESC11 | IF_ENFORCEENCRYPTICERTREQUEST disabled on CA |

## Prerequisites

- Windows Server with Active Directory and AD CS installed
- [AutomatedLab](https://automatedlab.org/) (for infrastructure deployment)
- [PSCertutil](https://github.com/jakehildreth/PSCertutil) module
- PowerShell 5.1+

## Installation

```powershell
Install-Module -Name ADCSGoat AllowPrerelase
```

Or clone the repo and import directly:

```powershell
git clone https://github.com/jakehildreth/ADCSGoat.git
Import-Module .\ADCSGoat\ADCSGoat\ADCSGoat.psd1
```

## Quick Start

```powershell
# Deploy lab infrastructure (Hyper-V + AutomatedLab)
Deploy-AGInfrastructure

# Install all vulnerable templates and CA misconfigurations
Install-ADCSGoat

# Clean up when done
Uninstall-ADCSGoat
```

## Commands

| Command | Description |
|---------|-------------|
| `Deploy-AGInfrastructure` | Deploys a Hyper-V lab using AutomatedLab |
| `Install-ADCSGoat` | Creates all vulnerable templates and CA misconfigs |
| `Uninstall-ADCSGoat` | Removes all ADCSGoat templates and reverts CA changes |
| `Find-AGEnrollmentService` | Queries AD for all Enrollment Services |
| `New-AGBlankTemplateObject` | Creates blank certificate template objects in AD |
| `Set-AGTemplateAce` | Adds ACEs to a certificate template |
| `Set-AGTemplateProperty` | Sets properties on a certificate template |
| `Set-AGEnrollmentServiceFullName` | Adds a FullName property to an Enrollment Service object |

## License

MIT License w/Commons Clause - see [LICENSE](..\LICENSE) file for details.

---

Made with 💜 by [Jake Hildreth](https://jakehildreth.com)

