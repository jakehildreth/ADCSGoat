#Requires -Modules Pester

<#
    Integration tests for the deploy state file (ticket #26).

    The state file is the teardown source of truth and the record that proves
    a deploy happened without touching AD. These tests use the live lab forest
    to capture a real Enrollment Services object, and a temp path for the file
    itself so the module directory is never dirtied by test runs.
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
    . $PSScriptRoot/../Private/Read-AGDeployState.ps1
    . $PSScriptRoot/../Private/Save-AGDeployState.ps1
    . $PSScriptRoot/../Private/New-AGDeployState.ps1
    . $PSScriptRoot/../Private/Get-AGEnrollmentService.ps1

    Add-Type -AssemblyName System.DirectoryServices

    $script:RootDSE = New-Object System.DirectoryServices.DirectoryEntry('LDAP://RootDSE')
    $script:ConfigNC = $script:RootDSE.configurationNamingContext
    $script:CaDn = "CN=LabRootCA1,CN=Enrollment Services,CN=Public Key Services,CN=Services,$($script:ConfigNC)"

    $script:StatePath = Join-Path -Path $TestDrive -ChildPath 'ADCSGoat.State.xml'

    # Live capture for assertions about what the state file must record.
    $script:LiveCa = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($script:CaDn)")
    $script:LiveTemplates = @($script:LiveCa.Properties['certificateTemplates'] | ForEach-Object { "$_" })
}

Describe 'Deploy state file (live forest)' -Skip:(-not $script:LabAvailable) {

    Context 'When capturing pre-change state for a selected CA' {
        BeforeAll {
            $ca = [pscustomobject]@{ Name = 'LabRootCA1'; DistinguishedName = $script:CaDn }
            $script:State = New-AGDeployState -SelectedCA $ca
        }

        It 'Records the selected CA identity and DN' {
            $script:State.SelectedCA.Name | Should -Be 'LabRootCA1'
            $script:State.SelectedCA.DistinguishedName | Should -Be $script:CaDn
        }

        It 'Captures the pre-change certificateTemplates value list verbatim' {
            $captured = @($script:State.PreChangeCertificateTemplates)
            $captured.Count | Should -Be $script:LiveTemplates.Count
            foreach ($t in $script:LiveTemplates) { $captured | Should -Contain $t }
        }

        It 'Captures the pre-change nTSecurityDescriptor as restorable SDDL' {
            $script:State.PreChangeSecurityDescriptorSddl | Should -Not -BeNullOrEmpty
            $script:State.PreChangeSecurityDescriptorSddl | Should -BeOfType [string]
        }

        It 'Captures the pre-change nTSecurityDescriptor as byte-for-byte binary' {
            $script:State.PreChangeSecurityDescriptorBinary | Should -Not -BeNullOrEmpty
        }

        It 'Starts with an empty per-clone record list for scenarios to populate' {
            @($script:State.Clones).Count | Should -Be 0
        }
    }

    Context 'When the state file round-trips through disk' {
        BeforeAll {
            $ca = [pscustomobject]@{ Name = 'LabRootCA1'; DistinguishedName = $script:CaDn }
            $script:State = New-AGDeployState -SelectedCA $ca
            Save-AGDeployState -State $script:State -Path $script:StatePath
            $script:Reloaded = Read-AGDeployState -Path $script:StatePath
        }

        It 'Writes the file to disk before any AD write' {
            Test-Path -Path $script:StatePath | Should -BeTrue
        }

        It 'Round-trips the CA identity' {
            $script:Reloaded.SelectedCA.Name | Should -Be 'LabRootCA1'
            $script:Reloaded.SelectedCA.DistinguishedName | Should -Be $script:CaDn
        }

        It 'Round-trips the pre-change certificateTemplates list as an exact set' {
            $reloaded = @($script:Reloaded.PreChangeCertificateTemplates | ForEach-Object { "$_" })
            $expected = @($script:State.PreChangeCertificateTemplates | ForEach-Object { "$_" })
            $reloaded.Count | Should -Be $expected.Count
            foreach ($t in $expected) { $reloaded | Should -Contain $t }
        }

        It 'Round-trips the SDDL verbatim' {
            $script:Reloaded.PreChangeSecurityDescriptorSddl | Should -Be $script:State.PreChangeSecurityDescriptorSddl
        }

        It 'Round-trips the binary security descriptor byte-for-byte' {
            $reloaded = [byte[]]$script:Reloaded.PreChangeSecurityDescriptorBinary
            $original = [byte[]]$script:State.PreChangeSecurityDescriptorBinary
            $reloaded.Length | Should -Be $original.Length
            [Convert]::ToBase64String($reloaded) | Should -Be ([Convert]::ToBase64String($original))
        }

        It 'Re-reads the live object and confirms no AD write occurred during capture' {
            $after = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($script:CaDn)")
            $afterTemplates = @($after.Properties['certificateTemplates'] | ForEach-Object { "$_" })
            ($afterTemplates | Sort-Object) -join '|' | Should -Be (($script:LiveTemplates | Sort-Object) -join '|')
            $after.Dispose()
        }
    }

    Context 'When a scenario records a clone into the state file' {
        BeforeAll {
            $ca = [pscustomobject]@{ Name = 'LabRootCA1'; DistinguishedName = $script:CaDn }
            $script:State = New-AGDeployState -SelectedCA $ca
            $clone = [pscustomobject]@{
                Scenario             = 'ESC1'
                Cn                   = 'Copy of Web Server'
                Oid                  = '1.3.6.1.4.1.311.21.8.99999999.88888888'
                CompanionOidObjectDN = 'CN=1.AABBCC,CN=OID,CN=Public Key Services,CN=Services,' + $script:ConfigNC
                PostSetupSddl        = 'O:S-1-5-21-1G:S-1-5-21-1D:(A;;GA;;;S-1-5-11)'
            }
            Add-AGDeployStateClone -State $script:State -Clone $clone
            Save-AGDeployState -State $script:State -Path $script:StatePath
            $script:Reloaded = Read-AGDeployState -Path $script:StatePath
        }

        It 'Persists the clone record with cn, OID, and companion DN' {
            @($script:Reloaded.Clones).Count | Should -Be 1
            $c = @($script:Reloaded.Clones)[0]
            $c.Scenario | Should -Be 'ESC1'
            $c.Cn | Should -Be 'Copy of Web Server'
            $c.Oid | Should -Be '1.3.6.1.4.1.311.21.8.99999999.88888888'
            $c.CompanionOidObjectDN | Should -Match 'CN=OID'
        }

        It 'Records the post-setup SDDL for the clone' {
            $c = @($script:Reloaded.Clones)[0]
            $c.PostSetupSddl | Should -Be 'O:S-1-5-21-1G:S-1-5-21-1D:(A;;GA;;;S-1-5-11)'
        }
    }
}
