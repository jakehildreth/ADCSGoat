#Requires -Modules Pester

<#
    Offline tests for the ESC4+ESC5 chain (ticket #30) decision seams. These
    run without a live forest.

    Three seams are covered:

    1. Deploy-AGEsc5Chain wiring — verified by shadowing its AD-touching
       collaborators with in-test fakes and asserting exactly what the scenario
       passes to them (source, destination, unpublished flag, CA-object grant).

    2. Test-AGAccessRulePresent — the real exported-from-file predicate that
       backs Set-AGEnrollmentServiceAce idempotency, exercised directly with
       real ActiveDirectoryAccessRule objects.

    3. Invoke-AGDeployTeardown ACL-last ordering — verified structurally against
       the function AST: the ACL restore must be the final AD write and must sit
       outside the try block that guards the certificateTemplates/delete steps.
#>

BeforeAll {
    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    $powerShellPath = (Get-Process -Id $PID).Path
}

Describe 'Deploy-AGEsc5Chain wiring (offline, mocked collaborators)' {
    It 'Clones Workstation unpublished and grants Auth Users GenericAll on the CA object' {
        $scriptPath = Join-Path -Path $TestDrive -ChildPath 'Wiring.ps1'
        @'
param($ModuleRoot)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.DirectoryServices

$script:Pipeline = $null
$script:Ace = $null
function Invoke-AGTemplateScenario {
    param($Scenario,$SourceName,$DestinationName,$Recipe,$AccessRules,$Principal,$AlsoPublishTemplate,$CAName,$StatePath,$Server,[switch]$SkipPublish,[switch]$Force)
    $script:Pipeline = @{ Scenario=$Scenario; SourceName=$SourceName; DestinationName=$DestinationName; SkipPublish=$SkipPublish.IsPresent; HasRecipe=($null -ne $Recipe) }
    [pscustomobject]@{ CloneCn=$DestinationName; Oid='1.2.3.4'; CompanionOidObjectDN='CN=x,CN=OID' }
}
function Get-AGEnrollmentService { param($CAName,$Server) [pscustomobject]@{ Name='CA1'; DistinguishedName='CN=CA1,CN=Enrollment Services' } }
function Set-AGEnrollmentServiceAce { param($DistinguishedName,$AccessRules,$Server) $script:Ace = @{ DN=$DistinguishedName; Rules=@($AccessRules) } }

. (Join-Path $ModuleRoot 'Public/Deploy-AGEsc5Chain.ps1')
Deploy-AGEsc5Chain -Force

if ($script:Pipeline.Scenario -ne 'ESC5Chain') { throw "Scenario=$($script:Pipeline.Scenario)" }
if ($script:Pipeline.SourceName -ne 'Workstation') { throw "Source=$($script:Pipeline.SourceName)" }
if ($script:Pipeline.DestinationName -ne 'Copy of Workstation') { throw "Dest=$($script:Pipeline.DestinationName)" }
if (-not $script:Pipeline.SkipPublish) { throw 'SkipPublish not set; clone would be published' }
if ($script:Pipeline.HasRecipe) { throw 'A recipe was supplied; the chain must make zero attribute overrides' }
if (-not $script:Ace) { throw 'Set-AGEnrollmentServiceAce not called' }
if ($script:Ace.DN -ne 'CN=CA1,CN=Enrollment Services') { throw "ACE DN=$($script:Ace.DN)" }
$rule = $script:Ace.Rules[0]
if ($rule.IdentityReference.Value -ne 'S-1-5-11') { throw "Trustee=$($rule.IdentityReference.Value)" }
if ($rule.ActiveDirectoryRights -ne [System.DirectoryServices.ActiveDirectoryRights]::GenericAll) { throw "Rights=$($rule.ActiveDirectoryRights)" }
if ($rule.AccessControlType -ne 'Allow') { throw "Type=$($rule.AccessControlType)" }
Write-Output 'WIRING OK'
'@ | Set-Content -Path $scriptPath -Encoding UTF8

        $output = & $powerShellPath -NoProfile -File $scriptPath -ModuleRoot $moduleRoot 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output | Out-String)
        $output | Should -Contain 'WIRING OK'
    }
}

Describe 'Test-AGAccessRulePresent (real predicate)' {
    BeforeAll {
        . (Join-Path -Path $moduleRoot -ChildPath 'Private/Set-AGEnrollmentServiceAce.ps1')
        $script:authUsers = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-11')
        $script:allProps = [guid]'00000000-0000-0000-0000-000000000000'
    }

    It 'Detects an identical rule as present' {
        $existing = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $authUsers, ([System.DirectoryServices.ActiveDirectoryRights]::GenericAll), ([System.Security.AccessControl.AccessControlType]::Allow), $allProps
        $probe = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $authUsers, ([System.DirectoryServices.ActiveDirectoryRights]::GenericAll), ([System.Security.AccessControl.AccessControlType]::Allow), $allProps
        Test-AGAccessRulePresent -ExistingRules @($existing) -Rule $probe | Should -BeTrue
    }

    It 'Does not dedupe a different right' {
        $existing = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $authUsers, ([System.DirectoryServices.ActiveDirectoryRights]::GenericAll), ([System.Security.AccessControl.AccessControlType]::Allow), $allProps
        $probe = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $authUsers, ([System.DirectoryServices.ActiveDirectoryRights]::GenericRead), ([System.Security.AccessControl.AccessControlType]::Allow), $allProps
        Test-AGAccessRulePresent -ExistingRules @($existing) -Rule $probe | Should -BeFalse
    }

    It 'Does not dedupe a different trustee' {
        $domainUsers = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-21-1-2-3-513')
        $existing = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $domainUsers, ([System.DirectoryServices.ActiveDirectoryRights]::GenericAll), ([System.Security.AccessControl.AccessControlType]::Allow), $allProps
        $probe = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $authUsers, ([System.DirectoryServices.ActiveDirectoryRights]::GenericAll), ([System.Security.AccessControl.AccessControlType]::Allow), $allProps
        Test-AGAccessRulePresent -ExistingRules @($existing) -Rule $probe | Should -BeFalse
    }

    It 'Returns false for an empty DACL' {
        $probe = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $authUsers, ([System.DirectoryServices.ActiveDirectoryRights]::GenericAll), ([System.Security.AccessControl.AccessControlType]::Allow), $allProps
        Test-AGAccessRulePresent -ExistingRules @() -Rule $probe | Should -BeFalse
    }
}

Describe 'Invoke-AGDeployTeardown ACL-last ordering (structural)' {
    BeforeAll {
        $script:teardownPath = Join-Path -Path $moduleRoot -ChildPath 'Private/Invoke-AGDeployTeardown.ps1'
        $tokens = $null; $errors = $null
        $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($teardownPath, [ref]$tokens, [ref]$errors)
        $script:funcBody = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-AGDeployTeardown' }, $false)
    }

    It 'Restores the security descriptor only after the guarded certificateTemplates/delete steps' {
        $text = $funcBody.Extent.Text
        $tryIndex = $text.IndexOf('try {')
        # The ACL restore writes the captured raw nTSecurityDescriptor bytes.
        $aclIndex = $text.IndexOf("nTSecurityDescriptor")
        $tryIndex | Should -BeGreaterThan -1
        $aclIndex | Should -BeGreaterThan -1
        $aclIndex | Should -BeGreaterThan $tryIndex -Because 'the ACL restore must come after the guarded steps'
    }

    It 'Wraps the certificateTemplates and clone-delete steps in the abort guard' {
        $text = $funcBody.Extent.Text
        $tryBlock = $text.Substring($text.IndexOf('try {'), $text.IndexOf('} catch {') - $text.IndexOf('try {'))
        $tryBlock | Should -Match 'certificateTemplates'
        $tryBlock | Should -Match 'Remove-AGTemplate'
        $tryBlock | Should -Not -Match 'nTSecurityDescriptor.*Value' -Because 'the ACL write must not be inside the guarded steps'
    }

    It 'Leaves the ACL restore outside the try/catch guard' {
        $text = $funcBody.Extent.Text
        $catchEnd = $text.IndexOf('TeardownAbortedBeforeAclRestore')
        # The ACL write assigns the captured bytes to the nTSecurityDescriptor property.
        $aclIndex = $text.IndexOf(".Properties['nTSecurityDescriptor'].Value")
        $aclIndex | Should -BeGreaterThan $catchEnd -Because 'the ACL restore runs after the catch, not inside the guard'
    }
}
