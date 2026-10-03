BeforeAll {
    Import-Module -Name PSFramework -ErrorAction Stop
    Import-Module -Name AutomatedLab -ErrorAction Stop
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\Public\Deploy-AGInfrastructure.ps1')

    $deploymentArguments = @{
        Name           = 'AGTest'
        Domain         = 'test.goat'
        ExternalSwitch = 'ExistingSwitch'
        Sources        = $TestDrive
        LabsRoot       = $TestDrive
        NonInteractive = $true
    }
}

Describe 'Deploy-AGInfrastructure' {
    BeforeEach {
        Mock -CommandName Get-Lab -MockWith {
            throw 'Resource validation must precede lab access.'
        }
    }

    It 'Rejects an unknown VM role before deployment' {
        {
            Deploy-AGInfrastructure @deploymentArguments -VMResources @{
                Client = @{ Memory = 4GB; Processors = 2 }
            }
        } | Should -Throw -ErrorId 'InvalidVMResources,Deploy-AGInfrastructure'
    }

    It 'Rejects <Reason> instead of deploying unsafe resources' -ForEach @(
        @{ Reason = 'startup memory below the Desktop Experience minimum'; Resources = @{ DC = @{ Memory = 1GB } } }
        @{ Reason = 'a memory value with string units'; Resources = @{ CA = @{ Memory = '8GB' } } }
        @{ Reason = 'a zero processor count'; Resources = @{ PAW = @{ Processors = 0 } } }
        @{ Reason = 'a fractional processor count'; Resources = @{ DC = @{ Processors = 1.5 } } }
        @{ Reason = 'an unsupported resource field'; Resources = @{ CA = @{ MaxMemory = 8GB } } }
        @{ Reason = 'startup memory above the AutomatedLab limit'; Resources = @{ DC = @{ Memory = 129GB } } }
        @{ Reason = 'a processor count above the AutomatedLab limit'; Resources = @{ CA = @{ Processors = 65 } } }
        @{ Reason = 'a nondictionary role configuration'; Resources = @{ PAW = 4GB } }
    ) {
        {
            Deploy-AGInfrastructure @deploymentArguments -VMResources $Resources
        } | Should -Throw -ErrorId 'InvalidVMResources,Deploy-AGInfrastructure'
    }

    Context 'Noninteractive deployment' {
        BeforeEach {
            Mock -CommandName Test-LabHostRemoting -MockWith { $true }
            Mock -CommandName Get-Lab -MockWith { @() }
            Mock -CommandName Read-Host -MockWith { throw 'Interactive input is unavailable.' }
            Mock -CommandName Get-VMSwitch -MockWith {
                [PSCustomObject]@{ Name = 'ExistingSwitch' }
            }
        }

        It 'Reports unprepared host remoting without starting an interactive setup' {
            Mock -CommandName Test-LabHostRemoting -MockWith { $false }
            Mock -CommandName Get-Lab -MockWith { throw 'Lab access preceded prerequisite validation.' }

            {
                Deploy-AGInfrastructure @deploymentArguments
            } | Should -Throw -ErrorId 'HostRemotingNotReady,Deploy-AGInfrastructure'
        }

        It 'Reports a duplicate lab name instead of requesting another name' {
            Mock -CommandName Get-Lab -MockWith { 'AGTest' }

            {
                Deploy-AGInfrastructure @deploymentArguments
            } | Should -Throw -ErrorId 'LabNameInUse,Deploy-AGInfrastructure'
        }

        It 'Reports a duplicate domain instead of requesting another domain' {
            Mock -CommandName Get-Lab -MockWith { 'OtherLab' }
            Mock -CommandName Import-Lab -MockWith { }
            Mock -CommandName Get-LabVM -MockWith {
                [PSCustomObject]@{ DomainName = 'test.goat' }
            }

            {
                Deploy-AGInfrastructure @deploymentArguments
            } | Should -Throw -ErrorId 'DomainInUse,Deploy-AGInfrastructure'
        }

        It 'Reports a missing external switch instead of requesting an adapter' {
            Mock -CommandName Get-VMSwitch -MockWith { @() }

            {
                Deploy-AGInfrastructure @deploymentArguments
            } | Should -Throw -ErrorId 'ExternalSwitchNotFound,Deploy-AGInfrastructure'
        }
    }
}
