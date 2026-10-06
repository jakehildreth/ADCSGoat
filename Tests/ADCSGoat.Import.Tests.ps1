BeforeAll {
    $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '../ADCSGoat.psd1'
    $powerShellPath = (Get-Process -Id $PID).Path
}

Describe 'ADCSGoat import' {
    It 'Exposes AD commands without AutomatedLab or PSFramework installed' {
        $scriptPath = Join-Path -Path $TestDrive -ChildPath 'Import-WithoutDeploymentModules.ps1'
        @'
param($ManifestPath)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = Join-Path -Path $PSHOME -ChildPath 'Modules'
Import-Module -Name $ManifestPath
$command = Get-Command -Name Deploy-ADCSGoat -Module ADCSGoat
if ($command.CommandType -ne 'Function') { throw 'The AD deployment command is unavailable.' }
if (Get-Module -Name AutomatedLab, PSFramework) { throw 'Import loaded deployment modules.' }
# Binding command metadata must not require a PSFramework attribute type.
$null = (Get-Command -Name Deploy-AGInfrastructure -Module ADCSGoat).Parameters
Write-Output 'AD commands available; deployment modules absent.'
'@ | Set-Content -Path $scriptPath -Encoding UTF8

        $output = & $powerShellPath -NoProfile -File $scriptPath -ManifestPath $manifestPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        $output | Should -Contain 'AD commands available; deployment modules absent.'
    }
}

Describe 'Deploy-AGInfrastructure prerequisites' {
    It 'Stops before deployment for <Scenario>' -ForEach @(
        @{ Scenario = 'an AutomatedLab installation failure'; Mode = 'Missing' }
        @{ Scenario = 'a transitive dependency installation failure'; Mode = 'TransitiveMissing' }
        @{ Scenario = 'a required dependency version installation failure'; Mode = 'TransitiveVersion' }
        @{ Scenario = 'an AutomatedLab initialization error'; Mode = 'BrokenImport' }
        @{ Scenario = 'an installer that leaves the required module unavailable'; Mode = 'InstallIncomplete' }
    ) {
        $moduleRoot = Join-Path -Path $TestDrive -ChildPath $Mode
        $null = New-Item -Path $moduleRoot -ItemType Directory
        if ($Mode -notin @('Missing', 'InstallIncomplete')) {
            $automatedLabRoot = Join-Path -Path $moduleRoot -ChildPath 'AutomatedLab'
            $null = New-Item -Path $automatedLabRoot -ItemType Directory
            $moduleParameters = @{
                Path = Join-Path -Path $automatedLabRoot -ChildPath 'AutomatedLab.psd1'
                RootModule = 'AutomatedLab.psm1'
                ModuleVersion = '1.0.0'
            }
            if ($Mode -like 'Transitive*') {
                $moduleParameters.RequiredModules = @('AutomatedLabCore')
                $coreRoot = Join-Path -Path $moduleRoot -ChildPath 'AutomatedLabCore'
                $null = New-Item -Path $coreRoot -ItemType Directory
                New-ModuleManifest -Path (Join-Path -Path $coreRoot -ChildPath 'AutomatedLabCore.psd1') -ModuleVersion '1.0.0' -RequiredModules @(@{ ModuleName = 'PSFramework'; ModuleVersion = '2.0.0' })
                if ($Mode -eq 'TransitiveVersion') {
                    $frameworkRoot = Join-Path -Path $moduleRoot -ChildPath 'PSFramework'
                    $null = New-Item -Path $frameworkRoot -ItemType Directory
                    New-ModuleManifest -Path (Join-Path -Path $frameworkRoot -ChildPath 'PSFramework.psd1') -ModuleVersion '1.0.0'
                }
            }
            New-ModuleManifest @moduleParameters
            "throw 'AutomatedLab fixture initialization failed.'" |
                Set-Content -Path (Join-Path -Path $automatedLabRoot -ChildPath 'AutomatedLab.psm1') -Encoding UTF8
        }

        $scriptPath = Join-Path -Path $moduleRoot -ChildPath 'Check-Prerequisites.ps1'
        @'
param($ManifestPath, $ModuleRoot, $Mode)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = $ModuleRoot + [IO.Path]::PathSeparator + (Join-Path -Path $PSHOME -ChildPath 'Modules')
function global:Install-Module {
    [CmdletBinding()]
    param($Name, $Repository, $Scope, [switch]$Force, $MinimumVersion, $MaximumVersion, $RequiredVersion)
    if ($Mode -eq 'InstallIncomplete') { return }
    throw [System.Net.WebException]::new('The fixture dependency repository is unavailable.')
}
Import-Module -Name $ManifestPath
try {
    # Omitted path arguments must not call AutomatedLab before its dependency check.
    Deploy-AGInfrastructure -NonInteractive
    throw 'Deployment did not report an unavailable dependency.'
} catch {
    if ($_.FullyQualifiedErrorId -ne 'InfrastructureDependencyUnavailable,Deploy-AGInfrastructure') { throw }
    if ($_.Exception.InnerException -isnot [Exception]) { throw 'The original dependency failure was lost.' }
    if ($Mode -notin @('BrokenImport', 'InstallIncomplete') -and $_.Exception.InnerException -isnot [System.Net.WebException]) {
        throw 'The original installation failure was lost.'
    }
    if ($_.TargetObject -ne 'AutomatedLab') { throw 'The failed prerequisite was not identified.' }
    Write-Output 'Deployment stopped at the dependency check.'
}
'@ | Set-Content -Path $scriptPath -Encoding UTF8

        $output = & $powerShellPath -NoProfile -File $scriptPath -ManifestPath $manifestPath -ModuleRoot $moduleRoot -Mode $Mode 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        $output | Should -Contain 'Deployment stopped at the dependency check.'
    }
}
