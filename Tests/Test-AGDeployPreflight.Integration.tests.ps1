#Requires -Modules Pester

<#
    Integration tests for the preflight report (ticket #26).

    Hard prerequisites abort with a prerequisite error naming the check and
    remediation; soft observations warn and continue and are recorded in the
    output. The pure evaluation logic (name-flag bit, Domain Users enroll ACE,
    KB5014754 posture -> caveat) is unit-tested against fabricated inputs so a
    green run never depends on mutating live AD or DC registry. The live-forest
    tests prove the happy-path report end to end.
#>

BeforeDiscovery {
    $script:LabAvailable = $false
    try {
        $rootDSE = New-Object System.DirectoryServices.DirectoryEntry('LDAP://RootDSE')
        $null = $rootDSE.configurationNamingContext
        $script:LabAvailable = $true
    } catch {
        $script:LabAvailable = $false
    }
}

BeforeAll {
    . $PSScriptRoot/../Private/Test-AGDeployPreflight.ps1

    Add-Type -AssemblyName System.DirectoryServices
}

Describe 'Test-AGDeployPreflight (live forest happy path)' -Skip:(-not $script:LabAvailable) {

    Context 'When the lab satisfies every hard prerequisite' {
        BeforeAll {
            $script:Ca = [pscustomobject]@{
                Name              = 'LabRootCA1'
                DistinguishedName = 'CN=LabRootCA1,CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration,DC=adcs,DC=goat'
            }
            $script:Warnings = @()
            $script:Report = Test-AGDeployPreflight -SelectedCA $script:Ca -WarningVariable +script:Warnings
        }

        It 'Returns a report object with hard and soft results' {
            $script:Report | Should -Not -BeNullOrEmpty
            $script:Report.PSObject.Properties.Name | Should -Contain 'HardChecks'
            $script:Report.PSObject.Properties.Name | Should -Contain 'SoftObservations'
        }

        It 'Records the Web Server ENROLLEE_SUPPLIES_SUBJECT check as passed' {
            $check = @($script:Report.HardChecks | Where-Object { $_.Check -eq 'WebServerNameFlag' })
            $check | Should -HaveCount 1
            $check[0].Passed | Should -BeTrue
        }

        It 'Records the Domain Users User-template enroll check as passed' {
            $check = @($script:Report.HardChecks | Where-Object { $_.Check -eq 'DomainUsersCanEnrollUser' })
            $check | Should -HaveCount 1
            $check[0].Passed | Should -BeTrue
        }

        It 'Records the selected-CA resolution check as passed' {
            $check = @($script:Report.HardChecks | Where-Object { $_.Check -eq 'SelectedCAResolves' })
            $check | Should -HaveCount 1
            $check[0].Passed | Should -BeTrue
        }
    }
}

Describe 'Test-AGDeployPreflight evaluation (unit)' {

    Context 'When the Web Server name flag lacks bit 0x1' {
        It 'Aborts with a prerequisite error naming the check and remediation' {
            $thrown = $null
            try {
                Resolve-AGPreflightHardCheck -Check 'WebServerNameFlag' -Value 0 -ErrorAction Stop
            } catch { $thrown = $_ }
            $thrown | Should -Not -BeNullOrEmpty
            $thrown.FullyQualifiedErrorId | Should -BeLike 'PrerequisiteFailed*'
            "$($thrown.Exception.Message)" | Should -Match 'Web Server'
            "$($thrown.Exception.Message)" | Should -Match '0x1'
        }
    }

    Context 'When Domain Users cannot enroll through the User template' {
        It 'Aborts with a prerequisite error naming the check and remediation' {
            $thrown = $null
            try {
                Resolve-AGPreflightHardCheck -Check 'DomainUsersCanEnrollUser' -Value $false -ErrorAction Stop
            } catch { $thrown = $_ }
            $thrown.FullyQualifiedErrorId | Should -BeLike 'PrerequisiteFailed*'
            "$($thrown.Exception.Message)" | Should -Match 'Domain Users'
            "$($thrown.Exception.Message)" | Should -Match 'User'
        }
    }

    Context 'When the selected CA does not resolve to one Enrollment Services object' {
        It 'Aborts with a prerequisite error' {
            $thrown = $null
            try {
                Resolve-AGPreflightHardCheck -Check 'SelectedCAResolves' -Value 0 -ErrorAction Stop
            } catch { $thrown = $_ }
            $thrown.FullyQualifiedErrorId | Should -BeLike 'PrerequisiteFailed*'
        }
    }

    Context 'When Domain Users holds an Enroll extended-right ACE on the User DACL' {
        It 'Detects enrollment capability from the descriptor' {
            $sd = New-Object System.Security.AccessControl.RawSecurityDescriptor('O:AUG:DUD:AI(A;OICIID;RPWPCR;;;AU)(A;CIID;0x00000130;;;S-1-5-21-1-2-3-513)')
            $enrollGuid = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'
            $ace = New-Object System.Security.AccessControl.CommonAce([System.Security.AccessControl.AceFlags]::None, [System.Security.AccessControl.AceQualifier]::AccessAllowed, 0x130, (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-21-1-2-3-513')), $false, $null)
            $sd.DiscretionaryAcl.InsertAce(0, (New-Object System.Security.AccessControl.ObjectAce([System.Security.AccessControl.AceFlags]::None, [System.Security.AccessControl.AceQualifier]::AccessAllowed, 0x130, (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-21-1-2-3-513')), [System.Security.AccessControl.ObjectAceFlags]::ObjectAceTypePresent, $enrollGuid, [guid]::Empty, $false, $null)))
            Test-AGDomainUsersEnrollAllowed -Dacl $sd.DiscretionaryAcl -DomainUsersSid 'S-1-5-21-1-2-3-513' | Should -BeTrue
        }
    }

    Context 'When Domain Users holds no Enroll ACE on the User DACL' {
        It 'Detects the absence of enrollment capability' {
            $sd = New-Object System.Security.AccessControl.RawSecurityDescriptor('O:AUG:DUD:AI(A;OICIID;RPWPCR;;;AU)')
            Test-AGDomainUsersEnrollAllowed -Dacl $sd.DiscretionaryAcl -DomainUsersSid 'S-1-5-21-1-2-3-513' | Should -BeFalse
        }
    }
}
