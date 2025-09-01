function Deploy-AGInfrastructure {
    <#
    TODO: Create 'PAW' as a Custom Role that includes RSAT.
    TODO: Accept Roles as Parameter.
    #>

    [CmdletBinding()]
    param (
        [PsfValidatePattern('^\w{1,11}$', ErrorMessage = 'Lab name must be no longer than 11 characters and only contain letters and numbers.')]
        $Name = 'Locksmith',
        [PsfValidatePattern('\.', ErrorMessage = 'Domain must contain at least one dot.')]
        $Domain = 'adcs.goat',
        $ExternalSwitch = 'External Switch',
        $Sources = (Get-LabSourcesLocation),
        $LabsRoot = "$((Get-PSFConfig -Module AutomatedLab -Name LabAppDataRoot).Value)\Labs", # Not currently needed, but I like it.,
        [switch]$Confirm
    )

    <#
    #requires -Modules Hyper-V, AutomatedLab -Version 7 -RunAsAdministrator
    #>

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
        Write-Host
        Write-Warning -Message "A lab using the domain `"$Domain`" already exists on this host."
        Write-Host "Please select a new root domain name: " -NoNewline
        $Domain = Read-Host
    }

    # Create a Hyper-V External Switch if none exists.
    while (-not (Get-VMSwitch | Where-Object Name -EQ $ExternalSwitch)) {
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
    $Roles = @('DC', 'CA', 'PAW')
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

    if (-not $Confirm) {
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

        $Answer = Get-PSFUserChoice -Caption 'Continue with deployment?' -Options Yes, No

        if ($Answer -eq 1) { exit }
    }

    # Define the lab + hypervisor
    New-LabDefinition -Name $Name -DefaultVirtualizationEngine HyperV

    # Use existing External Switch created or discovered above
    Add-LabVirtualNetworkDefinition -Name $ExternalSwitch -AddressSpace "$NetAdapterIP/24"

    # Set default parameters for all machines in the lab
    $PSDefaultParameterValues = @{
        'Add-LabMachineDefinition:Network'         = $ExternalSwitch
        'Add-LabMachineDefinition:ToolsPath'       = "$Sources\Tools"
        'Add-LabMachineDefinition:MinMemory'       = 512MB
        'Add-LabMachineDefinition:Memory'          = 1GB
        'Add-LabMachineDefinition:MaxMemory'       = 4GB
        'Add-LabMachineDefinition:Processors'      = 2
        'Add-LabMachineDefinition:DomainName'      = $Domain
        'Add-LabMachineDefinition:Gateway'         = $Gateway
        'Add-LabMachineDefinition:DnsServer1'      = $DCIP
        'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    }

    Add-LabMachineDefinition -Name "$Name-DC" -Roles RootDC -IpAddress $DCIP
    Add-LabMachineDefinition -Name "$Name-CA" -Roles CaRoot -IpAddress $CAIP
    Add-LabMachineDefinition -Name "$Name-PAW" -IpAddress $PAWIP

    Install-Lab

    Install-LabWindowsFeature -FeatureName RSAT -ComputerName "$Name-PAW" -IncludeAllSubFeature

    Show-LabDeploymentSummary
}
