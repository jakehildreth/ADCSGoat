BeforeAll {
    # Fake the directory classes so tests never query a real domain.
    Add-Type -AssemblyName System.DirectoryServices
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\Private\Find-AGPawComputer.ps1')
}

Describe 'Find-AGPawComputer' {
    BeforeEach {
        Mock -CommandName New-Object -ParameterFilter { $TypeName -eq 'System.DirectoryServices.DirectoryEntry' } -MockWith {
            [pscustomobject]@{ defaultNamingContext = 'DC=adcs,DC=goat' }
        }
    }

    It 'Returns the single matching PAW' {
        Mock -CommandName New-Object -ParameterFilter { $TypeName -eq 'System.DirectoryServices.DirectorySearcher' } -MockWith {
            $searcher = [pscustomobject]@{ SearchRoot = $null; Filter = $null; PropertiesToLoad = [System.Collections.ArrayList]::new() }
            $searcher | Add-Member -MemberType ScriptMethod -Name FindAll -Value {
                , @([pscustomobject]@{ Properties = @{ dnshostname = @('ADCSGoat-PAW.adcs.goat'); name = @('ADCSGoat-PAW') } })
            }
            $searcher
        }

        Find-AGPawComputer | Should -Be 'ADCSGoat-PAW.adcs.goat'
    }

    It 'Throws when no PAW exists' {
        Mock -CommandName New-Object -ParameterFilter { $TypeName -eq 'System.DirectoryServices.DirectorySearcher' } -MockWith {
            $searcher = [pscustomobject]@{ SearchRoot = $null; Filter = $null; PropertiesToLoad = [System.Collections.ArrayList]::new() }
            $searcher | Add-Member -MemberType ScriptMethod -Name FindAll -Value { , @() }
            $searcher
        }

        { Find-AGPawComputer } | Should -Throw '*none found*'
    }

    It 'Throws and lists the candidates when several PAWs exist' {
        Mock -CommandName New-Object -ParameterFilter { $TypeName -eq 'System.DirectoryServices.DirectorySearcher' } -MockWith {
            $searcher = [pscustomobject]@{ SearchRoot = $null; Filter = $null; PropertiesToLoad = [System.Collections.ArrayList]::new() }
            $searcher | Add-Member -MemberType ScriptMethod -Name FindAll -Value {
                , @(
                    [pscustomobject]@{ Properties = @{ dnshostname = @('A-PAW.adcs.goat'); name = @('A-PAW') } }
                    [pscustomobject]@{ Properties = @{ dnshostname = @('B-PAW.adcs.goat'); name = @('B-PAW') } }
                )
            }
            $searcher
        }

        { Find-AGPawComputer } | Should -Throw '*A-PAW.adcs.goat, B-PAW.adcs.goat*'
    }
}
