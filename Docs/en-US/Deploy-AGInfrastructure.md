---
external help file: ADCSGoat-help.xml
Module Name: ADCSGoat
online version: https://github.com/jakehildreth/ADCSGoat
schema: 2.0.0
---

# Deploy-AGInfrastructure

## SYNOPSIS

Deploys a three-VM Windows Server 2022 Standard Desktop Experience AD CS lab.

## SYNTAX

```powershell
Deploy-AGInfrastructure [[-Name] <Object>] [[-Domain] <Object>] [[-ExternalSwitch] <Object>]
    [[-Sources] <Object>] [[-LabsRoot] <Object>] [-Confirm]
    [-VMResources <Hashtable>] [-NonInteractive] [<CommonParameters>]
```

## DESCRIPTION

Defines a domain controller (DC), certification authority (CA), and privileged access workstation (PAW) with AutomatedLab and Hyper-V. All three VMs use `Windows Server 2022 Standard (Desktop Experience)`.

Interactive deployment suggests startup memory and CPUs for each VM. Press Enter to accept a suggestion. Enter startup memory as a whole number of GB, from 2 to 128, and CPUs as a whole number from 1 to 64. Invalid input shows a warning and repeats the same prompt.

The initial suggestion for each VM is 4 GB startup memory and 2 CPUs. Dynamic memory uses a 2 GB minimum. Maximum memory is the greater of 4 GB or the selected startup memory. The final configuration shows all effective memory bounds and CPU counts before deployment.

Memory units use PowerShell's binary `GB` constant: 1 GB is 1,073,741,824 bytes. These are lab suggestions, not host-aware capacity estimates. Reserve host memory in addition to the 12 GB aggregate guest startup suggestion.

## EXAMPLES

### Example 1: Accept or edit each suggestion

```powershell
Deploy-AGInfrastructure
```

Prompts for startup memory and CPUs for DC, CA, and PAW, then asks whether to deploy. Press Enter at each resource prompt to use the suggestion.

### Example 2: Deploy without input requests

```powershell
$resources = @{
    DC  = @{ Memory = 8GB; Processors = 4 }
    CA  = @{ Memory = 4GB }
    PAW = @{ Processors = 2 }
}

Deploy-AGInfrastructure -Name Goat2022 -Domain goat2022.test `
    -ExternalSwitch 'External Switch' -VMResources $resources -NonInteractive
```

Uses the supplied overrides and defaults for omitted fields. DC uses 2/8/8 GB minimum/startup/maximum memory and 4 CPUs. CA and PAW use 2/4/4 GB and 2 CPUs. The caller's resource dictionary is not changed.

Noninteractive deployment requires a unique lab name and domain, an existing external switch, and prepared AutomatedLab host remoting. It reports an error instead of requesting a new name, domain, adapter, or remoting-policy approval. It still displays the effective configuration.

## PARAMETERS

### -Name

Lab name. Defaults to `ADCSGoat`; the existing validation accepts up to 11 word characters. Interactive deployment requests another name if it is already used.

### -Domain

Root domain name. Defaults to `adcs.goat` and must contain a dot. Interactive deployment requests another domain if it is already used by a lab.

### -ExternalSwitch

Hyper-V external switch name. Defaults to `External Switch`. Interactive deployment can request a host adapter and create a missing switch. `-NonInteractive` requires the switch to exist already.

### -Sources

LabSources root used for the VM tools path. Defaults to `Get-LabSourcesLocation`. AutomatedLab discovers operating-system media through its configured ISO location.

### -LabsRoot

Legacy path shown in verbose initial configuration. Defaults to the `Labs` folder under AutomatedLab's configured application-data root. This parameter does not change AutomatedLab storage.

### -Confirm

Legacy switch that **skips** the final deployment confirmation. It is not the standard PowerShell confirmation behavior. It does not skip resource prompts. Use `-NonInteractive` for scripted deployment.

### -VMResources

Optional hashtable with role keys `DC`, `CA`, and `PAW`. Each value is a dictionary containing either or both of:

- `Memory`: integer startup memory in bytes, from `2GB` to `128GB`. Use a PowerShell size literal, such as `8GB`, not the string `'8GB'`.
- `Processors`: integer CPU count from 1 to 64.

Keys are case-insensitive. Unknown roles or fields and invalid values terminate with `InvalidVMResources` before lab access. Omitted fields use the 4 GB / 2 CPU suggestions. In interactive mode, overrides become the initial suggestions and can be changed at the prompts.

### -NonInteractive

Accepts effective resources without prompts and skips final confirmation. A duplicate lab name, duplicate domain, or missing switch terminates with `LabNameInUse`, `DomainInUse`, or `ExternalSwitchNotFound`, respectively. Unprepared host remoting terminates with `HostRemotingNotReady` before importing labs. Prepare AutomatedLab host remoting separately after reviewing its security implications. This mode does not select an adapter, resolve naming conflicts, or enable remoting policies automatically.

### CommonParameters

Supports the standard common parameters, including `-Verbose` and `-ErrorAction`. See [about_CommonParameters](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters).

## INPUTS

None. Does not accept pipeline input.

## OUTPUTS

None. Writes deployment status and configuration to the host.

## NOTES

Run as an administrator on a Hyper-V host. AutomatedLab and PSFramework load as required modules; installing ADCSGoat through the Gallery installs both dependencies. Installation does not enable Hyper-V, supply an OS ISO, or grant administrative rights.

Before deployment, use `Get-LabAvailableOperatingSystem` to verify that the configured media contains the exact `Windows Server 2022 Standard (Desktop Experience)` image. The Evaluation image has a different identifier and is not selected by this default.

Windows Server security defaults and current certificate-mapping enforcement can affect attack demonstrations. Configuring an ESC scenario does not prove that every historic attack path succeeds. Do not disable security policies merely to hide a deployment or authentication failure.

## RELATED LINKS

- [AutomatedLab](https://automatedlab.org/)
- [Windows Server hardware requirements](https://learn.microsoft.com/en-us/windows-server/get-started/hardware-requirements)
- [Certificate-based authentication changes](https://support.microsoft.com/en-us/topic/kb5014754-certificate-based-authentication-changes-on-windows-domain-controllers-ad2c23b0-15d8-4340-a468-4d4f3b188f16)
