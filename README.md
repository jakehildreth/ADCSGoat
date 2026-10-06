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

- PowerShell 5.1+
- For infrastructure deployment: an administrative Hyper-V host, matching Windows Server 2022 Standard Desktop Experience media, and PSGallery access when deployment dependencies are missing
- For template configuration: a domain with Active Directory and an enterprise AD CS CA
- [PSCertutil](https://github.com/jakehildreth/PSCertutil) is bundled in the built package; source imports require it separately

## Installation

```powershell
Install-Module -Name ADCSGoat
```

Installing or importing ADCSGoat does not install or load AutomatedLab or PSFramework. Commands that configure AD CS inside the VMs do not need them. `Deploy-AGInfrastructure` installs missing AutomatedLab dependencies on the deployment host. You can also prepare the host manually:

```powershell
Install-Module -Name AutomatedLab -Scope CurrentUser
```

`Deploy-AGInfrastructure` checks AutomatedLab's complete required-module graph before resolving path defaults or prompting. It installs missing modules and compatible dependency versions from PSGallery in `CurrentUser` scope, then imports AutomatedLab. Only unsatisfied requirements trigger installation. Installation or import failures terminate with `InfrastructureDependencyUnavailable` and preserve the original error. Dependency installation does not enable Hyper-V or supply OS media.

Or clone the repo and import directly:

```powershell
Install-Module -Name PSCertutil
git clone https://github.com/jakehildreth/ADCSGoat.git
Import-Module .\ADCSGoat\ADCSGoat.psd1
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

## Deployment resources

`Deploy-AGInfrastructure` uses Windows Server 2022 Standard Desktop Experience for DC, CA, and PAW. Confirm the exact image name with `Get-LabAvailableOperatingSystem` before deployment. Evaluation media uses a different identifier.

Each VM starts with these editable suggestions:

| VM | Minimum RAM | Startup RAM | Maximum RAM | CPUs |
|----|-------------|-------------|-------------|------|
| DC | 2 GB | 4 GB | 4 GB | 2 |
| CA | 2 GB | 4 GB | 4 GB | 2 |
| PAW | 2 GB | 4 GB | 4 GB | 2 |

Press Enter to accept a suggestion. Edit startup RAM in whole GB (2–128) and CPUs as a whole number (1–64). Dynamic maximum RAM increases when startup RAM exceeds 4 GB. Memory uses PowerShell's binary `GB` unit; reserve host RAM in addition to the 12 GB guest startup total.

For scripted deployment, supply per-VM overrides in bytes and use `-NonInteractive`:

```powershell
Deploy-AGInfrastructure -Name Goat2022 -Domain goat2022.test `
    -ExternalSwitch 'External Switch' `
    -VMResources @{ DC = @{ Memory = 8GB; Processors = 4 } } -NonInteractive
```

Omitted roles and fields keep their suggestions. Noninteractive mode requires unique names, an existing switch, and prepared AutomatedLab host remoting; it reports an error instead of requesting input or enabling remoting policies. The legacy `-Confirm` switch skips only the final confirmation, not resource prompts.

See [deployment help](Docs/en-US/Deploy-AGInfrastructure.md) for details. Windows Server security defaults and certificate-mapping enforcement can affect attack demonstrations; configured misconfigurations do not guarantee every historic attack path succeeds.

## Commands

| Command | Description |
|---------|-------------|
| `Deploy-ADCSGoat` | Runs the deploy entrypoint: selects the CA, prints the preflight report, writes the state file — before any AD write |
| `Deploy-AGInfrastructure` | Deploys a Hyper-V lab using AutomatedLab |
| `Install-ADCSGoat` | Creates all vulnerable templates and CA misconfigs |
| `Uninstall-ADCSGoat` | Removes all ADCSGoat templates and reverts CA changes |
| `Find-AGEnrollmentService` | Queries AD for all Enrollment Services |
| `New-AGBlankTemplateObject` | Creates blank certificate template objects in AD |
| `Set-AGTemplateAce` | Adds ACEs to a certificate template |
| `Set-AGTemplateProperty` | Sets properties on a certificate template |
| `Set-AGEnrollmentServiceFullName` | Adds a FullName property to an Enrollment Service object |
| `Copy-AGTemplate` | Clones a built-in certificate template with fresh OID and collision handling |
| `Deploy-AGEsc1` | Deploys the ESC1 scenario: clones Web Server, adds Client Auth, grants Domain Users enroll, publishes on the CA |
| `Deploy-AGEsc4` | Deploys the ESC4 scenario: clones Web Server to Test SSL, grants Domain Users Full Control, publishes on the CA |
| `Deploy-AGEsc3Chain` | Deploys the ESC3 chain: clones SubCA to VMware 6.x (no EKU override), grants Authenticated Users enroll, publishes VMware 6.x + User on the CA |

## License

MIT License w/Commons Clause - see [LICENSE](..\LICENSE) file for details.

---

Made with 💜 by [Jake Hildreth](https://jakehildreth.com)

