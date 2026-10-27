BeforeAll {
    # Declare the collaborators so these tests only check the wiring and ordering.
    function Find-AGPawComputer { param($Server) }
    function New-AGLowPrivUser { param($UserName, $Password, $Server) }
    function Remove-AGLowPrivUser { param($UserName, $Server) }
    function Test-AGLowPrivUserOwned { param($UserName, $Server) }
    function Set-AGRdpUserAccess { param($ComputerName, $Member, $Ensure) }
    function Get-ADDomainNameFromNc { param($ConfigurationNC, $Server) }
    function Invoke-AGDeployTeardown { param($StatePath, $Server) }
    function Deploy-AGEsc1 { param($StatePath, $CAName, $Server, $Force) }
    function Deploy-AGEsc4 { param($StatePath, $CAName, $Server, $Force) }
    function Deploy-AGEsc3Chain { param($StatePath, $CAName, $Server, $Force) }
    function Deploy-AGEsc5Chain { param($StatePath, $CAName, $Server, $Force) }
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\Public\Install-ADCSGoat.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\Public\Uninstall-ADCSGoat.ps1')
}

Describe 'Install-ADCSGoat low privileged user' {
    BeforeEach {
        $script:Calls = [System.Collections.Generic.List[string]]::new()
        Mock -CommandName New-Object -MockWith { [pscustomobject]@{ configurationNamingContext = 'CN=Configuration,DC=adcs,DC=goat' } }
        Mock -CommandName Get-ADDomainNameFromNc -MockWith { 'ADCS' }
        Mock -CommandName New-AGLowPrivUser -MockWith { $script:Calls.Add('New-AGLowPrivUser') }
        Mock -CommandName Find-AGPawComputer -MockWith { $script:Calls.Add('Find-AGPawComputer'); 'ADCSGoat-PAW.adcs.goat' }
        Mock -CommandName Set-AGRdpUserAccess -MockWith { $script:Calls.Add('Set-AGRdpUserAccess') }
        Mock -CommandName Deploy-AGEsc1 -MockWith { $script:Calls.Add('Deploy-AGEsc1') }
        Mock -CommandName Deploy-AGEsc4 -MockWith { }
        Mock -CommandName Deploy-AGEsc3Chain -MockWith { }
        Mock -CommandName Deploy-AGEsc5Chain -MockWith { }
    }

    It 'Creates the user, then finds the PAW, then grants RDP, then deploys the scenarios' {
        Install-ADCSGoat -StatePath (Join-Path $TestDrive 'state.xml')

        $script:Calls | Should -Be @('New-AGLowPrivUser', 'Find-AGPawComputer', 'Set-AGRdpUserAccess', 'Deploy-AGEsc1')
        Should -Invoke -CommandName Set-AGRdpUserAccess -Times 1 -ParameterFilter {
            $ComputerName -eq 'ADCSGoat-PAW.adcs.goat' -and $Member -eq 'ADCS\user' -and $Ensure -eq 'Present'
        }
    }

    It 'Still creates the user when the PAW cannot be found, and deploys nothing' {
        Mock -CommandName Find-AGPawComputer -MockWith { throw 'Expected exactly one computer named *-PAW' }

        { Install-ADCSGoat -StatePath (Join-Path $TestDrive 'state.xml') } | Should -Throw '*-PAW*'

        Should -Invoke -CommandName New-AGLowPrivUser -Times 1
        Should -Invoke -CommandName Deploy-AGEsc1 -Times 0
    }

    It 'Uses -PawComputerName without searching AD for the PAW' {
        Install-ADCSGoat -StatePath (Join-Path $TestDrive 'state.xml') -PawComputerName 'Goat2022-PAW'

        Should -Invoke -CommandName Find-AGPawComputer -Times 0
        Should -Invoke -CommandName Set-AGRdpUserAccess -Times 1 -ParameterFilter { $ComputerName -eq 'Goat2022-PAW' }
    }

    It 'Skips the user and the PAW entirely with -SkipLowPrivUser' {
        Install-ADCSGoat -StatePath (Join-Path $TestDrive 'state.xml') -SkipLowPrivUser

        Should -Invoke -CommandName New-AGLowPrivUser -Times 0
        Should -Invoke -CommandName Find-AGPawComputer -Times 0
        Should -Invoke -CommandName Set-AGRdpUserAccess -Times 0
        Should -Invoke -CommandName Deploy-AGEsc1 -Times 1
    }

    It 'Rejects <Name> as a user name' -ForEach @(
        @{ Name = 'a filter-breaking value'; Value = 'a)(objectClass=*' }
        @{ Name = 'a DN-breaking value'; Value = 'x,OU=Domain Controllers' }
        @{ Name = 'a wildcard'; Value = '*' }
        @{ Name = 'a name over 20 characters'; Value = 'abcdefghijklmnopqrstu' }
    ) {
        { Install-ADCSGoat -StatePath (Join-Path $TestDrive 'state.xml') -LowPrivUserName $Value } | Should -Throw
        Should -Invoke -CommandName New-AGLowPrivUser -Times 0
    }
}

Describe 'Uninstall-ADCSGoat low privileged user' {
    BeforeEach {
        $script:Calls = [System.Collections.Generic.List[string]]::new()
        Mock -CommandName New-Object -MockWith { [pscustomobject]@{ configurationNamingContext = 'CN=Configuration,DC=adcs,DC=goat' } }
        Mock -CommandName Get-ADDomainNameFromNc -MockWith { 'ADCS' }
        Mock -CommandName Test-AGLowPrivUserOwned -MockWith { $true }
        Mock -CommandName Find-AGPawComputer -MockWith { 'ADCSGoat-PAW.adcs.goat' }
        Mock -CommandName Set-AGRdpUserAccess -MockWith { $script:Calls.Add('Set-AGRdpUserAccess') }
        Mock -CommandName Remove-AGLowPrivUser -MockWith { $script:Calls.Add('Remove-AGLowPrivUser') }
        Mock -CommandName Invoke-AGDeployTeardown -MockWith { $script:Calls.Add('Invoke-AGDeployTeardown') }
    }

    It 'Removes the RDP access, then the user, then tears the deployment down' {
        Uninstall-ADCSGoat -StatePath (Join-Path $TestDrive 'state.xml')

        $script:Calls | Should -Be @('Set-AGRdpUserAccess', 'Remove-AGLowPrivUser', 'Invoke-AGDeployTeardown')
        Should -Invoke -CommandName Set-AGRdpUserAccess -Times 1 -ParameterFilter {
            $ComputerName -eq 'ADCSGoat-PAW.adcs.goat' -and $Member -eq 'ADCS\user' -and $Ensure -eq 'Absent'
        }
    }

    It 'Leaves the RDP access of an account ADCSGoat did not create' {
        Mock -CommandName Test-AGLowPrivUserOwned -MockWith { $false }

        Uninstall-ADCSGoat -StatePath (Join-Path $TestDrive 'state.xml')

        Should -Invoke -CommandName Set-AGRdpUserAccess -Times 0
        Should -Invoke -CommandName Find-AGPawComputer -Times 0
        # The helper still runs so it can warn that it is keeping the account.
        Should -Invoke -CommandName Remove-AGLowPrivUser -Times 1
        Should -Invoke -CommandName Invoke-AGDeployTeardown -Times 1
    }

    It 'Warns and carries on when the PAW cannot be found' {
        Mock -CommandName Find-AGPawComputer -MockWith { throw 'Expected exactly one computer named *-PAW' }

        Uninstall-ADCSGoat -StatePath (Join-Path $TestDrive 'state.xml') -WarningVariable warnings -WarningAction SilentlyContinue

        "$warnings" | Should -BeLike '*Could not remove*'
        Should -Invoke -CommandName Remove-AGLowPrivUser -Times 1
        Should -Invoke -CommandName Invoke-AGDeployTeardown -Times 1
    }

    It 'Skips the user entirely with -SkipLowPrivUser' {
        Uninstall-ADCSGoat -StatePath (Join-Path $TestDrive 'state.xml') -SkipLowPrivUser

        Should -Invoke -CommandName Test-AGLowPrivUserOwned -Times 0
        Should -Invoke -CommandName Set-AGRdpUserAccess -Times 0
        Should -Invoke -CommandName Remove-AGLowPrivUser -Times 0
        Should -Invoke -CommandName Invoke-AGDeployTeardown -Times 1
    }
}
