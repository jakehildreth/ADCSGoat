BeforeAll {
    $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '../ADCSGoat.psd1'
    $powerShellPath = (Get-Process -Id $PID).Path
}

Describe 'Deploy-AGInfrastructure automatic prerequisites' {
    It 'Installs absent AutomatedLab before checking host remoting' {
        $scriptPath = Join-Path -Path $TestDrive -ChildPath 'Install-MissingAutomatedLab.ps1'
        @'
param($ManifestPath, $ModuleRoot)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = $ModuleRoot + [IO.Path]::PathSeparator + (Join-Path -Path $PSHOME -ChildPath 'Modules')
function global:Install-Module {
    [CmdletBinding()]
    param($Name, $Repository, $Scope, [switch]$Force)
    if ($Name -ne 'AutomatedLab' -or $Repository -ne 'PSGallery' -or $Scope -ne 'CurrentUser') {
        throw 'Installation did not target the deployment module in the current user scope.'
    }
    $target = Join-Path -Path $ModuleRoot -ChildPath 'AutomatedLab'
    $null = New-Item -Path $target -ItemType Directory -Force
    'function Test-LabHostRemoting { $false }' | Set-Content -Path (Join-Path -Path $target -ChildPath 'AutomatedLab.psm1') -Encoding UTF8
    New-ModuleManifest -Path (Join-Path -Path $target -ChildPath 'AutomatedLab.psd1') -RootModule 'AutomatedLab.psm1' -ModuleVersion '1.0.0' -FunctionsToExport 'Test-LabHostRemoting'
}
Import-Module -Name $ManifestPath
try {
    Deploy-AGInfrastructure -Sources $ModuleRoot -LabsRoot $ModuleRoot -NonInteractive
    throw 'Deployment continued past unprepared host remoting.'
} catch {
    if ($_.FullyQualifiedErrorId -ne 'HostRemotingNotReady,Deploy-AGInfrastructure') { throw }
    Write-Output 'Missing AutomatedLab installed; host remoting checked.'
}
'@ | Set-Content -Path $scriptPath -Encoding UTF8

        $moduleRoot = Join-Path -Path $TestDrive -ChildPath 'Modules'
        $null = New-Item -Path $moduleRoot -ItemType Directory
        $output = & $powerShellPath -NoProfile -File $scriptPath -ManifestPath $manifestPath -ModuleRoot $moduleRoot 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        $output | Should -Contain 'Missing AutomatedLab installed; host remoting checked.'
    }

    It 'Prepares <Scenario> without deploying VMs' -ForEach @(
        @{ Scenario = 'a missing transitive dependency'; Mode = 'MissingDependency'; Requirement = @{ ModuleName = 'PSFramework'; ModuleVersion = '2.0.0' }; InitialVersion = ''; ExpectedVersion = '3.0.0' }
        @{ Scenario = 'a minimum dependency version'; Mode = 'MinimumVersion'; Requirement = @{ ModuleName = 'PSFramework'; ModuleVersion = '2.0.0' }; InitialVersion = '1.0.0'; ExpectedVersion = '3.0.0' }
        @{ Scenario = 'an exact dependency version'; Mode = 'RequiredVersion'; Requirement = @{ ModuleName = 'PSFramework'; RequiredVersion = '2.0.0' }; InitialVersion = '3.0.0'; ExpectedVersion = '2.0.0' }
        @{ Scenario = 'a bounded dependency version'; Mode = 'MaximumVersion'; Requirement = @{ ModuleName = 'PSFramework'; ModuleVersion = '1.0.0'; MaximumVersion = '2.0.0' }; InitialVersion = '3.0.0'; ExpectedVersion = '2.0.0' }
        @{ Scenario = 'already installed dependencies without repository access'; Mode = 'AlreadyInstalled'; Requirement = @{ ModuleName = 'PSFramework'; ModuleVersion = '2.0.0' }; InitialVersion = '3.0.0'; ExpectedVersion = '3.0.0' }
    ) {
        $scenarioRoot = Join-Path -Path $TestDrive -ChildPath $Mode
        $repositoryRoot = Join-Path -Path $scenarioRoot -ChildPath 'Repository'
        $moduleRoot = Join-Path -Path $scenarioRoot -ChildPath 'Modules'
        $null = New-Item -Path $moduleRoot -ItemType Directory -Force
        foreach ($name in @('AutomatedLab', 'AutomatedLabCore', 'PSFramework')) {
            $versions = if ($name -eq 'PSFramework') { @('1.0.0', '2.0.0', '3.0.0') } else { @('1.0.0') }
            foreach ($version in $versions) {
                $versionRoot = Join-Path -Path (Join-Path -Path $repositoryRoot -ChildPath $name) -ChildPath $version
                $null = New-Item -Path $versionRoot -ItemType Directory -Force
                $parameters = @{
                    Path = Join-Path -Path $versionRoot -ChildPath "$name.psd1"
                    ModuleVersion = $version
                }
                if ($name -eq 'AutomatedLab') {
                    $parameters.RootModule = 'AutomatedLab.psm1'
                    $parameters.RequiredModules = @('AutomatedLabCore')
                    $parameters.FunctionsToExport = @('Test-LabHostRemoting')
                    'function Test-LabHostRemoting { $false }' |
                        Set-Content -Path (Join-Path -Path $versionRoot -ChildPath 'AutomatedLab.psm1') -Encoding UTF8
                } elseif ($name -eq 'AutomatedLabCore') {
                    $parameters.RequiredModules = @($Requirement)
                }
                New-ModuleManifest @parameters
            }
        }
        foreach ($name in @('AutomatedLab', 'AutomatedLabCore')) {
            Copy-Item -Path (Join-Path -Path $repositoryRoot -ChildPath $name) -Destination $moduleRoot -Recurse
        }
        if ($InitialVersion) {
            $frameworkRoot = Join-Path -Path $moduleRoot -ChildPath 'PSFramework'
            $null = New-Item -Path $frameworkRoot -ItemType Directory
            Copy-Item -Path (Join-Path -Path $repositoryRoot -ChildPath "PSFramework/$InitialVersion") -Destination $frameworkRoot -Recurse
        }

        $scriptPath = Join-Path -Path $scenarioRoot -ChildPath 'Prepare-Dependencies.ps1'
        @'
param($ManifestPath, $ModuleRoot, $RepositoryRoot, $Mode, $ExpectedVersion)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = $ModuleRoot + [IO.Path]::PathSeparator + (Join-Path -Path $PSHOME -ChildPath 'Modules')
function global:Install-Module {
    [CmdletBinding()]
    param($Name, $Repository, $Scope, [switch]$Force, $MinimumVersion, $MaximumVersion, $RequiredVersion)
    if ($Mode -eq 'AlreadyInstalled') { throw 'Compatible dependencies must not need repository access.' }
    if ($Repository -ne 'PSGallery' -or $Scope -ne 'CurrentUser') { throw 'Unexpected installation source or scope.' }
    $candidates = Get-ChildItem -Path (Join-Path -Path $RepositoryRoot -ChildPath $Name) -Directory |
        Where-Object {
            (-not $MinimumVersion -or [version]$_.Name -ge [version]$MinimumVersion) -and
            (-not $MaximumVersion -or [version]$_.Name -le [version]$MaximumVersion) -and
            (-not $RequiredVersion -or [version]$_.Name -eq [version]$RequiredVersion)
        } | Sort-Object -Property @{ Expression = { [version]$_.Name }; Descending = $true }
    if (-not $candidates) { throw 'No repository module satisfies the requested version.' }
    $target = Join-Path -Path $ModuleRoot -ChildPath $Name
    $null = New-Item -Path $target -ItemType Directory -Force
    Copy-Item -Path @($candidates)[0].FullName -Destination $target -Recurse -Force
}
Import-Module -Name $ManifestPath
try {
    Deploy-AGInfrastructure -Sources $ModuleRoot -LabsRoot $ModuleRoot -NonInteractive
    throw 'Deployment continued past unprepared host remoting.'
} catch {
    if ($_.FullyQualifiedErrorId -ne 'HostRemotingNotReady,Deploy-AGInfrastructure') { throw }
}
$framework = Get-Module -Name PSFramework -All
if ($framework.Version -ne [version]$ExpectedVersion) { throw 'Deployment imported an incompatible dependency version.' }
Write-Output 'Dependency graph ready; host remoting checked.'
'@ | Set-Content -Path $scriptPath -Encoding UTF8

        $output = & $powerShellPath -NoProfile -File $scriptPath -ManifestPath $manifestPath -ModuleRoot $moduleRoot -RepositoryRoot $repositoryRoot -Mode $Mode -ExpectedVersion $ExpectedVersion 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        $output | Should -Contain 'Dependency graph ready; host remoting checked.'
    }
}
