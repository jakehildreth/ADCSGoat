function Deploy-AGInfrastructure {
    <#
    .SYNOPSIS
    Deploys a three-VM Windows Server 2025 Desktop Experience AD CS lab.

    .DESCRIPTION
    Defines a domain controller, certification authority, and privileged access
    workstation with AutomatedLab and Hyper-V. Prompts for each VM's startup
    memory and processor count. Enter accepts the suggestion. Dynamic memory
    uses a 2 GB minimum and the greater of 4 GB or startup memory as its maximum.
    Displays effective resources before deployment.

    .PARAMETER Name
    Lab name, up to 11 word characters. Defaults to ADCSGoat.

    .PARAMETER Domain
    Root domain name. Defaults to adcs.goat and must contain a dot.

    .PARAMETER ExternalSwitch
    Hyper-V external switch name. Interactive deployment can create it.

    .PARAMETER Sources
    LabSources root used for the VM tools path. Defaults to AutomatedLab's location.

    .PARAMETER LabsRoot
    Legacy path shown in verbose configuration. Does not change AutomatedLab storage.

    .PARAMETER Confirm
    Legacy switch that skips final deployment confirmation, not resource prompts.

    .PARAMETER VMResources
    Per-VM overrides keyed by DC, CA, and PAW. Each dictionary accepts Memory
    in bytes (2 GB to 128 GB) and Processors (1 to 64). Unspecified values use
    4 GB startup memory and 2 processors. For example: @{ DC = @{ Memory = 8GB } }.
    Interactive prompts start from these overrides and can change them.

    .PARAMETER NonInteractive
    Accepts effective resource values and skips all prompts. A duplicate lab
    name or domain, a missing switch, or unprepared host remoting terminates
    with an error. Host remoting must be configured separately.

    .EXAMPLE
    Deploy-AGInfrastructure
    Prompts for resources and confirms deployment using the suggested profile.

    .EXAMPLE
    Deploy-AGInfrastructure -Name Goat2025 -Domain goat2025.test -ExternalSwitch 'External Switch' -VMResources @{ DC = @{ Memory = 8GB; Processors = 4 } } -NonInteractive
    Deploys without input requests, using an existing switch and per-VM overrides.

    .OUTPUTS
    None. Writes deployment status and configuration to the host.

    .NOTES
    Requires an administrative Hyper-V host and media that enumerates as
    Windows Server 2025 Datacenter (Desktop Experience). Evaluation images have
    a different identifier. Memory units use PowerShell's binary GB constant.
    AutomatedLab and PSFramework load as module requirements.
    #>

    [CmdletBinding()]
    param (
        [PsfValidatePattern('^\w{1,11}$', ErrorMessage = 'Lab name must be no longer than 11 characters and only contain letters and numbers.')]
        $Name = 'ADCSGoat',
        [PsfValidatePattern('\.', ErrorMessage = 'Domain must contain at least one dot.')]
        $Domain = 'adcs.goat',
        $ExternalSwitch = 'External Switch',
        $Sources = (Get-LabSourcesLocation),
        $LabsRoot = "$((Get-PSFConfig -Module AutomatedLab -Name LabAppDataRoot).Value)\Labs", # Not currently needed, but I like it.,
        [switch]$Confirm,
        [ValidateNotNull()]
        [hashtable]$VMResources = @{},
        [switch]$NonInteractive
    )

    $roles = @('DC', 'CA', 'PAW')
    $effectiveResources = @{}
    foreach ($role in $roles) {
        $effectiveResources[$role] = @{ Memory = 4GB; Processors = 2 }
    }

    foreach ($role in $VMResources.Keys) {
        $resourceError = $null
        $overrides = $VMResources[$role]
        if ($role -notin $roles) {
            $resourceError = "Unknown VM role '$role'. Use DC, CA, or PAW."
        } elseif ($overrides -isnot [System.Collections.IDictionary]) {
            $resourceError = "VMResources '$role' must be a dictionary of Memory and Processors."
        } else {
            foreach ($field in $overrides.Keys) {
                [long]$value = 0
                if ($field -notin @('Memory', 'Processors')) {
                    $resourceError = "Unknown resource '$field' for '$role'. Use Memory or Processors."
                } elseif (-not [long]::TryParse([string]$overrides[$field], [ref]$value)) {
                    $resourceError = "Resource '$field' for '$role' must be an integer. Specify Memory in bytes, for example 8GB."
                } elseif ($field -eq 'Memory' -and ($value -lt 2GB -or $value -gt 128GB)) {
                    $resourceError = "Startup memory for '$role' must be between 2 GB and 128 GB."
                } elseif ($field -eq 'Processors' -and ($value -lt 1 -or $value -gt 64)) {
                    $resourceError = "Processors for '$role' must be between 1 and 64."
                } else {
                    $effectiveResources[$role][$field] = $value
                }

                if ($resourceError) { break }
            }
        }

        if ($resourceError) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new($resourceError),
                'InvalidVMResources',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $overrides
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    if ($NonInteractive.IsPresent -and -not (Test-LabHostRemoting -ErrorAction Stop)) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new('Prepare host remoting for AutomatedLab before using -NonInteractive.'),
            'HostRemotingNotReady',
            [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
            $env:COMPUTERNAME
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    Write-Verbose -Message @"

----------------------------------------------------
|              Initial Configuration               |
----------------------------------------------------

Name           = $Name
Domain         = $Domain
ExternalSwitch = $ExternalSwitch
Sources        = $Sources
LabRoot        = $LabsRoot
"@

    # Confirm lab name is unique on this host.
    while ((Get-Lab -List) -contains $Name) {
        if ($NonInteractive.IsPresent) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("A lab named '$Name' already exists. Specify a unique -Name."),
                'LabNameInUse',
                [System.Management.Automation.ErrorCategory]::ResourceExists,
                $Name
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        Write-Host
        Write-Warning -Message "A lab named `"$Name`" already exists on this host."
        Write-Host "Please select a new lab name: " -NoNewline
        $Name = Read-Host
    }

    # Import existing labs and add their domains to an array.
    Write-Host "`nImporting existing labs to confirm the new root domain name `"$Domain`" is unique."
    $ExistingDomains = Get-Lab -List | ForEach-Object {
        Import-Lab -Name $_
        Get-LabVM | Select-Object DomainName
    }

    $ExistingDomains = $ExistingDomains | Sort-Object -Property DomainName -Unique
    if ($ExistingDomains) { Write-Verbose "Existing Domains: $($ExistingDomains.DomainName)" }

    # Confirm root domain name is unique on this host.
    while ($ExistingDomains.DomainName -contains $Domain) {
        if ($NonInteractive.IsPresent) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("Domain '$Domain' is already used by another lab. Specify a unique -Domain."),
                'DomainInUse',
                [System.Management.Automation.ErrorCategory]::ResourceExists,
                $Domain
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        Write-Host
        Write-Warning -Message "A lab using the domain `"$Domain`" already exists on this host."
        Write-Host "Please select a new root domain name: " -NoNewline
        $Domain = Read-Host
    }

    # Create a Hyper-V External Switch if none exists.
    while (-not (Get-VMSwitch | Where-Object Name -EQ $ExternalSwitch)) {
        if ($NonInteractive.IsPresent) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("External switch '$ExternalSwitch' does not exist. Create it before noninteractive deployment."),
                'ExternalSwitchNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $ExternalSwitch
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        #region Select NetAdapter for Use in Lab
        $netIPAddressCollection = Get-NetIPAddress | Where-Object {
            $_.IPAddress -notmatch '^169.254|^127.0.0' -and
            $_.InterfaceAlias -notmatch 'VMware' -and
            $_.AddressFamily -eq 'IPv4' -and
            $_.PrefixLength -eq 24 -and
            $_.PrefixOrigin -eq 'Dhcp'
        }

        Write-Host @"
This script is designed to use a single network adapter with the following configuration:

- has an IPv4 address
- does not have an IP address in a link-local block
- is configured for DHCP
- has a subnet mask of /24

Only network adapters meeting this configuration are shown below.

Select the network adapter you'd like to use in your lab.
"@

        # Enumerate network adapters on the host.
        $i = 0
        $netIPAddressCollection | ForEach-Object {
            $i++
            Write-Host "  ${i}: $($_.InterfaceAlias) ($($_.IPAddress))"
        }
        [int]$adapterIndex = Read-Host -Prompt "Please enter a number `[1-$i`]"

        $adapterIndex = $adapterIndex - 1

        $NetAdapterName = $netIPAddressCollection[$($adapterIndex)].InterfaceAlias
        #endregion Select NetAdapter for Use in Lab

        # Create a new External Switch named $ExternalSwitch aka 'vEthernet ($ExternalSwitch)'
        try {
            New-VMSwitch -Name $ExternalSwitch -NetAdapterName $NetAdapterName -ErrorAction Stop
            Start-Sleep -Seconds 5
        } catch {
            throw $_
        }
    }

    # Get IP Address of External Switch
    [string]$NetAdapterIP = (Get-NetIPConfiguration -InterfaceAlias "vEthernet ($ExternalSwitch)").IPv4Address

    # Create required addresses
    if ($NetAdapterIP -match '(?:\d{1,3}\.){3}') {
        $BaseAddress = $matches[0]
        $NetworkAddress = $BaseAddress + '0'
        $Gateway = $BaseAddress + '1'
    }

    # Get IP Address of other machines in subnet
    $ExistingIPs = Get-VM |
    Where-Object State -EQ Running |
    Select-Object -ExpandProperty NetworkAdapters |
    Select-Object -ExpandProperty IPAddresses |
    ForEach-Object {
        if ($_ -match '(?:\d{1,3}\.){3}') { $_ }
    }

    # Pick IP Addresses for new VMs
    $NewIPs = @{}
    $RoleIndex = 0

    for ($i = 3; $i -lt 255 -and $RoleIndex -lt $Roles.Count; $i++) {
        $CandidateIP = "$BaseAddress$i"
        if ($ExistingIPs -notcontains $CandidateIP) {
            $NewIPs[$Roles[$RoleIndex]] = $CandidateIP
            $RoleIndex++
        }
    }

    # Create IPs for each role.
    $Roles | ForEach-Object {
        New-Variable -Name "${_}IP" -Value $NewIPs[$_]
    }

    if (-not $NonInteractive.IsPresent) {
        foreach ($role in $roles) {
            foreach ($field in @('Memory', 'Processors')) {
                $label = if ($field -eq 'Memory') { 'startup memory in GB' } else { 'processors' }
                $suggestion = if ($field -eq 'Memory') {
                    $effectiveResources[$role].Memory / 1GB
                } else {
                    $effectiveResources[$role].Processors
                }
                $minimum = if ($field -eq 'Memory') { 2 } else { 1 }
                $maximum = if ($field -eq 'Memory') { 128 } else { 64 }

                while ($true) {
                    $inputValue = Read-Host -Prompt "$role $label [$suggestion]"
                    if ([string]::IsNullOrWhiteSpace($inputValue)) { break }

                    [long]$enteredValue = 0
                    if ([long]::TryParse($inputValue, [ref]$enteredValue) -and
                        $enteredValue -ge $minimum -and $enteredValue -le $maximum) {
                        $effectiveResources[$role][$field] = if ($field -eq 'Memory') {
                            $enteredValue * 1GB
                        } else {
                            $enteredValue
                        }
                        break
                    }

                    Write-Warning -Message "$role $label must be a whole number between $minimum and $maximum."
                }
            }
        }
    }

    foreach ($role in $roles) {
        $effectiveResources[$role].MinMemory = 2GB
        $effectiveResources[$role].MaxMemory = [Math]::Max([long]4GB, [long]$effectiveResources[$role].Memory)
    }

    Write-PSFHostColor @"
----------------------------------------------------
|                Lab Configuration                 |
----------------------------------------------------
Name:                             <c='em'>$Name</c>
Root Domain:                      <c='em'>$Domain</c>
Network Address:                  <c='em'>$NetworkAddress</c>
Gateway:                          <c='em'>$Gateway</c>
Domain Controller IP:             <c='em'>$DCIP</c>
Certification Authority IP:       <c='em'>$CAIP</c>
Privileged Access Workstation IP: <c='em'>$PAWIP</c>
"@

    Write-Host "`nVM resources (dynamic memory):"
    foreach ($role in $roles) {
        $resources = $effectiveResources[$role]
        Write-Host ('{0,-16} Min {1:g} GB | Startup {2:g} GB | Max {3:g} GB | CPUs {4}' -f
            "$Name-$role", ($resources.MinMemory / 1GB), ($resources.Memory / 1GB),
            ($resources.MaxMemory / 1GB), $resources.Processors)
    }

    if (-not $Confirm.IsPresent -and -not $NonInteractive.IsPresent) {
        $Answer = Get-PSFUserChoice -Caption 'Continue with deployment?' -Options Yes, No
        if ($Answer -eq 1) { return }
    }

    # Define the lab + hypervisor
    New-LabDefinition -Name $Name -DefaultVirtualizationEngine HyperV

    # Use existing External Switch created or discovered above
    Add-LabVirtualNetworkDefinition -Name $ExternalSwitch -AddressSpace "$NetAdapterIP/24"

    # Set default parameters for all machines in the lab
    $PSDefaultParameterValues = @{
        'Add-LabMachineDefinition:Network'         = $ExternalSwitch
        'Add-LabMachineDefinition:ToolsPath'       = "$Sources\Tools"
        'Add-LabMachineDefinition:DomainName'      = $Domain
        'Add-LabMachineDefinition:Gateway'         = $Gateway
        'Add-LabMachineDefinition:DnsServer1'      = $DCIP
        'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2025 Datacenter (Desktop Experience)'
    }

    $dcResources = $effectiveResources['DC']
    $caResources = $effectiveResources['CA']
    $pawResources = $effectiveResources['PAW']
    Add-LabMachineDefinition -Name "$Name-DC" -Roles RootDC -IpAddress $DCIP @dcResources
    Add-LabMachineDefinition -Name "$Name-CA" -Roles CaRoot -IpAddress $CAIP @caResources
    Add-LabMachineDefinition -Name "$Name-PAW" -IpAddress $PAWIP @pawResources

    Install-Lab

    Install-LabWindowsFeature -FeatureName RSAT -ComputerName "$Name-PAW" -IncludeAllSubFeature

    Show-LabDeploymentSummary
}

