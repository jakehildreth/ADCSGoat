function Install-ADCSGoat {
    <#
    .SYNOPSIS
        Deploys the full ADCSGoat lab by running the four scenario deploys.

    .DESCRIPTION
        Orchestrates the four-scenario design settled in ADCSGoat issue #19 and
        completed in issue #30. Each scenario clones a built-in template,
        applies its recipe and rights, publishes (or deliberately withholds)
        per its design, and records state for teardown:

        - ESC1        Deploy-AGEsc1       — "Copy of Web Server" (Web Server +
                                            Client Auth), Domain Users enroll,
                                            published.
        - ESC4        Deploy-AGEsc4       — "Test SSL" (verbatim Web Server),
                                            Domain Users Full Control,
                                            published.
        - ESC2+SchemaV1 Deploy-AGEsc3Chain — "VMware 6.x" (SubCA clone) +
                                            built-in User published,
                                            Authenticated Users enroll.
        - ESC4+ESC5   Deploy-AGEsc5Chain  — "Copy of Workstation" (Workstation
                                            clone), Domain Users Full Control,
                                            NOT published; Authenticated Users
                                            Full Control on the CA object.

        All scenarios target a single selected enterprise CA and write a state
        file used by Uninstall-ADCSGoat for byte-exact teardown.

    .PARAMETER CAName
        The cn of the enterprise CA to target. Optional; autodetected when the
        forest has exactly one enterprise CA.

    .PARAMETER StatePath
        Where the deploy state file lives. Defaults to ADCSGoat.State.xml next
        to the module root.

    .PARAMETER Server
        The domain controller to write to. Defaults to the logon server.

    .PARAMETER Force
        Replaces ADCSGoat-owned existing clones without prompting. Required for
        non-interactive redeploy.

    .PARAMETER SkipLowPrivUser
        Skips creating the low privileged lab user and its RDP access to the PAW.

    .PARAMETER LowPrivUserName
        The sAMAccountName of the low privileged lab user. Defaults to 'user'.

    .PARAMETER LowPrivUserPassword
        The lab user's password. Defaults to the deliberately known 'Somepass1'.

    .PARAMETER PawComputerName
        The workstation the lab user may RDP to. Found in AD when omitted: the one
        computer named '*-PAW'. Zero or several matches stop the install; pass this
        parameter then. Runs locally when this is the current computer, otherwise
        through PowerShell remoting, which needs admin rights on the PAW.

    .EXAMPLE
        Install-ADCSGoat

        Creates the low privileged RDP user, then deploys all four scenarios
        against the forest's single CA.

    .EXAMPLE
        Install-ADCSGoat -CAName 'LabRootCA1' -Force -SkipLowPrivUser

        Redeploys all four scenarios against the named CA without the lab user.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'AD writes gated by the per-scenario collision prompt / -Force contract per module precedent.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'The lab user is a deliberately known, low privileged credential.')]
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CAName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$StatePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$SkipLowPrivUser,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LowPrivUserName = 'user',

        [Parameter()]
        [securestring]$LowPrivUserPassword = (ConvertTo-SecureString -String 'Somepass1' -AsPlainText -Force),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PawComputerName
    )

    begin {
        if ([string]::IsNullOrEmpty($StatePath)) {
            $StatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ADCSGoat.State.xml'
        }
        $scenarioParams = @{ StatePath = $StatePath }
        if ($PSBoundParameters.ContainsKey('CAName')) { $scenarioParams['CAName'] = $CAName }
        if ($PSBoundParameters.ContainsKey('Server')) { $scenarioParams['Server'] = $Server }
        if ($Force.IsPresent) { $scenarioParams['Force'] = $true }
    }

    process {
        # First, so an unreachable PAW fails before any template is written to AD.
        if (-not $SkipLowPrivUser) {
            $userParams = @{}
            if ($PSBoundParameters.ContainsKey('Server')) { $userParams['Server'] = $Server }

            # Resolved before the user is created so an unknown PAW fails with nothing written.
            if (-not $PSBoundParameters.ContainsKey('PawComputerName')) {
                $PawComputerName = Find-AGPawComputer @userParams
            }

            $null = New-AGLowPrivUser -UserName $LowPrivUserName -Password $LowPrivUserPassword @userParams

            $serverPrefix = if ($Server) { "LDAP://$Server/" } else { 'LDAP://' }
            $rootDSE = New-Object System.DirectoryServices.DirectoryEntry("${serverPrefix}RootDSE")
            $netbiosName = Get-ADDomainNameFromNc -ConfigurationNC "$($rootDSE.configurationNamingContext)" @userParams
            Set-AGRdpUserAccess -ComputerName $PawComputerName -Member "$netbiosName\$LowPrivUserName" -Ensure Present
        }

        Deploy-AGEsc1 @scenarioParams
        Deploy-AGEsc4 @scenarioParams
        Deploy-AGEsc3Chain @scenarioParams
        Deploy-AGEsc5Chain @scenarioParams
    }
}
