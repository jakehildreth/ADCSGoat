#Requires -Modules Pester

<#
    Integration tests for the selected-CA contract (ticket #26).

    Slice 1: Get-AGEnrollmentService CA selection against the live lab forest.
    The lab forest has exactly one enterprise CA (LabRootCA1), which exercises
    the autodetect path for real. Multi-CA and invalid-name rejection are pure
    resolution logic and are covered by unit tests with mocked discovery.
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
    . $PSScriptRoot/../Private/Get-AGEnrollmentService.ps1

    Add-Type -AssemblyName System.DirectoryServices

    $script:RootDSE = New-Object System.DirectoryServices.DirectoryEntry('LDAP://RootDSE')
    $script:ConfigNC = $script:RootDSE.configurationNamingContext
    $script:ExpectedDn = "CN=LabRootCA1,CN=Enrollment Services,CN=Public Key Services,CN=Services,$($script:ConfigNC)"
}

Describe 'Get-AGEnrollmentService (live forest, single CA)' -Skip:(-not $script:LabAvailable) {

    Context 'When -CAName is omitted and the forest has exactly one enterprise CA' {
        It 'Autodetects the single CA and returns its identity' {
            $result = Get-AGEnrollmentService
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'LabRootCA1'
            $result.DistinguishedName | Should -Be $script:ExpectedDn
        }

        It 'Identifies the CA as host-FQDN backslash CA-name (certutil format)' {
            $result = Get-AGEnrollmentService
            $result.FullName | Should -Be 'ADCSGoat-CA.adcs.goat\LabRootCA1'
        }
    }

    Context 'When -CAName names the existing CA' {
        It 'Resolves the named CA to its Enrollment Services object' {
            $result = Get-AGEnrollmentService -CAName 'LabRootCA1'
            $result.DistinguishedName | Should -Be $script:ExpectedDn
        }

        It 'Is case-insensitive on the CA name' {
            $result = Get-AGEnrollmentService -CAName 'labrootca1'
            $result.DistinguishedName | Should -Be $script:ExpectedDn
        }
    }

    Context 'When -CAName names a CA that does not exist' {
        It 'Fails before any AD write with an error listing the available CAs' {
            $thrown = $null
            try { Get-AGEnrollmentService -CAName 'NoSuchCA' -ErrorAction Stop } catch { $thrown = $_ }
            $thrown | Should -Not -BeNullOrEmpty
            "$($thrown.Exception.Message)" | Should -Match 'LabRootCA1'
        }

        It 'Tags the failure with a stable, scriptable error id' {
            $thrown = $null
            try { Get-AGEnrollmentService -CAName 'NoSuchCA' -ErrorAction Stop } catch { $thrown = $_ }
            $thrown.FullyQualifiedErrorId | Should -BeLike 'CANotFound*'
        }
    }
}

Describe 'Get-AGEnrollmentService selection resolution (unit)' {

    Context 'When discovery finds multiple enterprise CAs and -CAName is omitted' {
        It 'Fails listing every CA and demanding -CAName' {
            $candidates = @(
                [pscustomobject]@{ Name = 'CA-One'; DistinguishedName = 'CN=CA-One,CN=Enrollment Services' }
                [pscustomobject]@{ Name = 'CA-Two'; DistinguishedName = 'CN=CA-Two,CN=Enrollment Services' }
            )
            $thrown = $null
            try { Resolve-AGEnrollmentServiceSelection -Candidates $candidates -CAName $null -ErrorAction Stop } catch { $thrown = $_ }
            $thrown | Should -Not -BeNullOrEmpty
            "$($thrown.Exception.Message)" | Should -Match 'CA-One'
            "$($thrown.Exception.Message)" | Should -Match 'CA-Two'
            "$($thrown.Exception.Message)" | Should -Match 'CAName'
        }

        It 'Tags the ambiguity with a stable, scriptable error id' {
            $candidates = @(
                [pscustomobject]@{ Name = 'CA-One'; DistinguishedName = 'x' }
                [pscustomobject]@{ Name = 'CA-Two'; DistinguishedName = 'y' }
            )
            $thrown = $null
            try { Resolve-AGEnrollmentServiceSelection -Candidates $candidates -CAName $null -ErrorAction Stop } catch { $thrown = $_ }
            $thrown.FullyQualifiedErrorId | Should -BeLike 'MultipleCAsFound*'
        }
    }

    Context 'When discovery finds zero enterprise CAs and -CAName is omitted' {
        It 'Fails stating no enterprise CA exists in the forest' {
            $thrown = $null
            try { Resolve-AGEnrollmentServiceSelection -Candidates @() -CAName $null -ErrorAction Stop } catch { $thrown = $_ }
            $thrown.FullyQualifiedErrorId | Should -BeLike 'NoEnterpriseCAFound*'
        }
    }
}
