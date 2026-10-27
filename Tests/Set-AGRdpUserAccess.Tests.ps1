BeforeAll {
    # Declare external command boundaries so tests never touch a real computer.
    function Get-LocalGroupMember { param($Group) }
    function Add-LocalGroupMember { param($Group, $Member) }
    function Remove-LocalGroupMember { param($Group, $Member) }
    function Invoke-Command { param($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction) }
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\Private\Set-AGRdpUserAccess.ps1')
}

Describe 'Set-AGRdpUserAccess' {
    BeforeEach {
        Mock -CommandName Get-LocalGroupMember -MockWith { }
        Mock -CommandName Add-LocalGroupMember -MockWith { }
        Mock -CommandName Remove-LocalGroupMember -MockWith { }
        Mock -CommandName Invoke-Command -MockWith { }
    }

    It 'Adds the member when running on the target computer' {
        Set-AGRdpUserAccess -ComputerName $env:COMPUTERNAME -Member 'ADCS\user' -Ensure Present

        Should -Invoke -CommandName Add-LocalGroupMember -Times 1 -ParameterFilter {
            $Group -eq 'Remote Desktop Users' -and $Member -eq 'ADCS\user'
        }
        Should -Invoke -CommandName Invoke-Command -Times 0
    }

    It 'Does not re-add a member that is already in the group' {
        Mock -CommandName Get-LocalGroupMember -MockWith { [pscustomobject]@{ Name = 'ADCS\USER' } }

        Set-AGRdpUserAccess -ComputerName $env:COMPUTERNAME -Member 'ADCS\user' -Ensure Present

        Should -Invoke -CommandName Add-LocalGroupMember -Times 0
    }

    It 'Removes an existing member' {
        Mock -CommandName Get-LocalGroupMember -MockWith { [pscustomobject]@{ Name = 'ADCS\user' } }

        Set-AGRdpUserAccess -ComputerName $env:COMPUTERNAME -Member 'ADCS\user' -Ensure Absent

        Should -Invoke -CommandName Remove-LocalGroupMember -Times 1
    }

    It 'Does nothing when removing a member that is not in the group' {
        Set-AGRdpUserAccess -ComputerName $env:COMPUTERNAME -Member 'ADCS\user' -Ensure Absent

        Should -Invoke -CommandName Remove-LocalGroupMember -Times 0
    }

    It 'Uses remoting for a different computer' {
        Set-AGRdpUserAccess -ComputerName 'ADCSGoat-PAW.adcs.goat' -Member 'ADCS\user' -Ensure Present

        Should -Invoke -CommandName Invoke-Command -Times 1 -ParameterFilter {
            $ComputerName -eq 'ADCSGoat-PAW.adcs.goat'
        }
        Should -Invoke -CommandName Add-LocalGroupMember -Times 0
    }
}
