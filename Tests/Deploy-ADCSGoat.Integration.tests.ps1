#Requires -Modules Pester

<#
    Integration tests for the deploy spine entrypoint (ticket #26).

    Deploy-ADCSGoat composes the selected-CA contract, the preflight report,
    and the state file. These tests prove the ordering contract end to end on
    the live lab forest:

      selection -> preflight (hard/soft) -> state capture -> state file on disk

    all before any AD write. The spine performs no scenario writes itself, so
    the whole thing must leave the forest byte-identical.
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
    . $PSScriptRoot/../Public/Deploy-ADCSGoat.ps1
    . $PSScriptRoot/../Private/Get-AGEnrollmentService.ps1
    . $PSScriptRoot/../Private/Test-AGDeployPreflight.ps1
    . $PSScriptRoot/../Private/New-AGDeployState.ps1
    . $PSScriptRoot/../Private/Save-AGDeployState.ps1
    . $PSScriptRoot/../Private/Read-AGDeployState.ps1

    Add-Type -AssemblyName System.DirectoryServices

    $script:RootDSE = New-Object System.DirectoryServices.DirectoryEntry('LDAP://RootDSE')
    $script:ConfigNC = $script:RootDSE.configurationNamingContext
    $script:CaDn = "CN=LabRootCA1,CN=Enrollment Services,CN=Public Key Services,CN=Services,$($script:ConfigNC)"
    $script:StatePath = Join-Path -Path $TestDrive -ChildPath 'ADCSGoat.State.xml'
}

Describe 'Deploy-ADCSGoat orchestration (live forest)' -Skip:(-not $script:LabAvailable) {

    Context 'When run against the single-CA lab without -CAName' {
        BeforeAll {
            # Snapshot the CA object before the run so the no-AD-write
            # guarantee is verified, not assumed.
            $before = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($script:CaDn)")
            $script:BeforeTemplates = @($before.Properties['certificateTemplates'] | ForEach-Object { "$_" } | Sort-Object)
            $script:BeforeSddl = $before.ObjectSecurity.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::All)
            $before.Dispose()

            $script:Result = Deploy-ADCSGoat -StatePath $script:StatePath
        }

        It 'Autodetects the single CA and returns the report plus state' {
            $script:Result | Should -Not -BeNullOrEmpty
            $script:Result.SelectedCA.Name | Should -Be 'LabRootCA1'
        }

        It 'Writes the state file to disk' {
            Test-Path -Path $script:StatePath | Should -BeTrue
        }

        It 'State file records the CA identity, pre-change template list, and security descriptor' {
            $state = Read-AGDeployState -Path $script:StatePath
            $state.SelectedCA.DistinguishedName | Should -Be $script:CaDn
            @($state.PreChangeCertificateTemplates) | Should -Not -BeNullOrEmpty
            $state.PreChangeSecurityDescriptorSddl | Should -Not -BeNullOrEmpty
            @($state.PreChangeSecurityDescriptorBinary).Count | Should -BeGreaterThan 0
        }

        It 'Includes the preflight report in the output' {
            $script:Result.PSObject.Properties.Name | Should -Contain 'PreflightReport'
            @($script:Result.PreflightReport.HardChecks).Count | Should -BeGreaterThan 0
        }

        It 'Performs zero AD writes (certificateTemplates unchanged)' {
            $after = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($script:CaDn)")
            $afterTemplates = @($after.Properties['certificateTemplates'] | ForEach-Object { "$_" } | Sort-Object)
            $after.Dispose()
            ($afterTemplates -join '|') | Should -Be ($script:BeforeTemplates -join '|')
        }

        It 'Performs zero AD writes (security descriptor unchanged)' {
            $after = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($script:CaDn)")
            $afterSddl = $after.ObjectSecurity.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::All)
            $after.Dispose()
            $afterSddl | Should -Be $script:BeforeSddl
        }
    }

    Context 'When -CAName is invalid' {
        It 'Aborts before any AD write and writes no state file' {
            $stalePath = Join-Path -Path $TestDrive -ChildPath 'never.xml'
            $thrown = $null
            try { Deploy-ADCSGoat -CAName 'NoSuchCA' -StatePath $stalePath -ErrorAction Stop } catch { $thrown = $_ }
            $thrown | Should -Not -BeNullOrEmpty
            $thrown.FullyQualifiedErrorId | Should -BeLike 'CANotFound*'
            Test-Path -Path $stalePath | Should -BeFalse
        }
    }

    Context 'When a hard prerequisite fails' {
        It 'Aborts before writing the state file' {
            $stalePath = Join-Path -Path $TestDrive -ChildPath 'never2.xml'
            $thrown = $null
            # A selected-CA override whose DN does not resolve forces the
            # SelectedCAResolves hard check to fail after selection succeeds,
            # proving preflight runs (and aborts) before the state file write.
            $brokenCa = [pscustomobject]@{ Name = 'LabRootCA1'; FullName = 'ADCSGoat-CA.adcs.goat\LabRootCA1'; DistinguishedName = 'CN=LabRootCA1,CN=DoesNotExist,DC=adcs,DC=goat' }
            try {
                Deploy-ADCSGoat -SelectedCA $brokenCa -StatePath $stalePath -ErrorAction Stop
            } catch { $thrown = $_ }
            $thrown | Should -Not -BeNullOrEmpty
            $thrown.FullyQualifiedErrorId | Should -BeLike 'PrerequisiteFailed*'
            Test-Path -Path $stalePath | Should -BeFalse
        }
    }
}
