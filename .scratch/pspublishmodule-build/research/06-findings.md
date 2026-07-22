# 06 · Dependencies & Template Files — Research Findings
<!-- status: findings-complete | 2026-07-22 | constraint-update: PSCertutil must be vendored -->

## Sources consulted

| File | Key evidence extracted |
|------|----------------------|
| `ADCSGoat/ADCSGoat.psd1` | `RequiredModules` fully commented out; PSCertutil and AutomatedLab appear as comments only |
| `ADCSGoat/ADCSGoat.psm1` | Dot-sources all `Public/*.ps1` and `Private/*.ps1` recursively |
| `ADCSGoat/Public/Install-ADCSGoat.ps1` | Calls `Enable-PSCEditFlag`, `Disable-PSCInterfaceFlag` (PSCertutil); loads `.xml` via `Import-Clixml` at a `$PSScriptRoot`-relative path |
| `ADCSGoat/Public/Uninstall-ADCSGoat.ps1` | Calls `Disable-PSCEditFlag`, `Enable-PSCInterfaceFlag` (PSCertutil) |
| `ADCSGoat/Public/Deploy-AGInfrastructure.ps1` | Calls AutomatedLab and PSFramework functions; `[PsfValidatePattern]` attribute on params |
| `ADCSGoat/Private/Template/` | 18 files: 6×`.ps1` (data hashtables), 6×`.xml` (CliXml, runtime-required), 6×`.json` |
| `Locksmith2/Build/Build-Module.ps1` | **Authoritative vendoring reference** — complete implementation |
| `Locksmith2/Build/Invoke-LS2PostBuildPublish.ps1` | **Authoritative vendoring reference** — `Save-Module` + `Update-ModuleManifest -NestedModules` |
| `Locksmith2/Locksmith2.psd1` (source) | PSCertutil absent from all module fields; only built-in ExternalModuleDependencies |
| `Locksmith2/.gitignore` | `Artefacts/*` is ignored — no on-disk build output exists to inspect |
| `Stepper/Build/Build-Module.ps1` | Simpler reference (no vendoring); `MergeModuleOnBuild` confirmed |
| `Stepper/Artefacts/Unpacked/Stepper/` | Ground-truth of what PSPublishModule 2.0.27 outputs after merge: `Images/` (root-level dir) copied; `Private/` and `Public/` are NOT present — merged into PSM1 |

---

## 1. ADCSGoat's actual external module usage

### PSCertutil
Called in two public functions. **Must be vendored** (ticket constraint; follows Locksmith2 pattern).

| Function | PSCertutil calls |
|----------|-----------------|
| `Install-ADCSGoat` | `Enable-PSCEditFlag -CAFullName … -Flag EDITF_ATTRIBUTESUBJECTALTNAME2` (ESC6) |
| `Install-ADCSGoat` | `Disable-PSCInterfaceFlag -CAFullName … -Flag IF_ENFORCEENCRYPTICERTREQUEST` (ESC11) |
| `Uninstall-ADCSGoat` | `Disable-PSCEditFlag -CAFullName … -Flag EDITF_ATTRIBUTESUBJECTALTNAME2` |
| `Uninstall-ADCSGoat` | `Enable-PSCInterfaceFlag -CAFullName … -Flag IF_ENFORCEENCRYPTICERTREQUEST` |

Sources: `ADCSGoat/Public/Install-ADCSGoat.ps1:48-59`, `ADCSGoat/Public/Uninstall-ADCSGoat.ps1:36-49`

### AutomatedLab + PSFramework
Used exclusively in `Deploy-AGInfrastructure.ps1`. Cannot be vendored or merged. Soft, optional runtime deps.

**AutomatedLab calls**: `Get-LabSourcesLocation`, `Get-PSFConfig` (via AL), `Get-Lab`, `Import-Lab`, `Get-LabVM`, `New-LabDefinition`, `Add-LabVirtualNetworkDefinition`, `Add-LabMachineDefinition`, `Install-Lab`, `Install-LabWindowsFeature`, `Show-LabDeploymentSummary`

**PSFramework calls**: `[PsfValidatePattern(…)]` attribute, `Write-PSFHostColor`, `Get-PSFUserChoice`, `Get-PSFConfig`

Source: `ADCSGoat/Public/Deploy-AGInfrastructure.ps1` (entire function body)

### Built-in only — all remaining functions
All other public functions (`Find-AGEnrollmentService`, `New-AGBlankTemplateObject`, `Set-AGTemplateAce`, `Set-AGTemplateProperty`, `Set-AGEnrollmentServiceFullName`, `Publish-AGCertifcateTemplate`) use only `System.DirectoryServices` (via `Add-Type -AssemblyName`) and `Microsoft.PowerShell.*` cmdlets. No third-party modules.

---

## 2. How Locksmith2 vendors PSCertutil — the exact three-phase pattern

The Locksmith2 approach has three distinct phases. ADCSGoat must replicate all three.

### Phase 1 — Build-time analysis pre-flight (BEFORE `Build-Module {}`)

```powershell
# Locksmith2/Build/Build-Module.ps1 lines ~47-52
# Install PSCertutil on the build machine so PSPublishModule's AST analyser
# can attribute function calls to their source module, enabling IgnoreModuleName to work.
foreach ($depName in @('PSWriteHTML', 'PSCertutil')) {
    if (-not (Get-Module -Name $depName -ListAvailable)) {
        Write-Host "Installing $depName for build-time analysis..."
        Install-Module -Name $depName -Scope CurrentUser -Force -AllowClobber
    }
}
```

**Why this is necessary**: PSPublishModule's static analyser resolves function names (e.g. `Enable-PSCEditFlag`) to the module that exports them. Without PSCertutil installed at analysis time, the analyser cannot find the function and will either error or silently produce wrong output. Installing it here is build-time only — it is NOT the copy that ships to users.

### Phase 2 — Inside `Build-Module {}` — skip static analysis

```powershell
# Locksmith2/Build/Build-Module.ps1 — inside Build-Module {} block
New-ConfigurationModuleSkip -IgnoreModuleName 'PSWriteHtml', 'PSCertutil'
```

This single line does the critical work: it tells PSPublishModule to **not attempt to copy, inline, or declare** any functions whose source module is PSCertutil. Without it, PSPublishModule would either try to merge PSCertutil's functions into the PSM1 (if listed as ApprovedModule) or error when it finds calls to an unknown module's functions.

**Note**: The commented-out block confirms the evolution of this decision:
```powershell
# New-ConfigurationModule -Type ApprovedModule -Name @(
#     'PSWriteHTML', 'PSCertutil'
# )
```
ApprovedModule was tried first and abandoned in favour of ModuleSkip + post-build vendoring. ApprovedModule would attempt to inline the function source, which is fragile and bypasses version pinning.

**Also note**: PSCertutil does NOT appear in any `New-ConfigurationModule` call inside `Build-Module {}`. It is not an ExternalModule, not a RequiredModule, not an ApprovedModule — it is simply silenced by ModuleSkip.

### Phase 3 — Post-build vendoring (AFTER `Build-Module {}` returns)

This runs OUTSIDE the `Build-Module {}` scriptblock. The function is dot-sourced from a companion script, then called with the artefact path:

```powershell
# Locksmith2/Build/Build-Module.ps1 — after the Build-Module {} block closes
. "$PSScriptRoot\Invoke-LS2PostBuildPublish.ps1"

$postBuildParams = @{
    ArtefactRoot       = Join-Path $PSScriptRoot '..\Artefacts\Unpacked\Locksmith2'
    PublishToPSGallery = $PublishToPSGallery
}
if ($PSGalleryAPIKey)  { $postBuildParams['PSGalleryAPIKey']  = $PSGalleryAPIKey }
if ($PSGalleryAPIPath) { $postBuildParams['PSGalleryAPIPath'] = $PSGalleryAPIPath }

Invoke-LS2PostBuildPublish @postBuildParams
```

Inside `Invoke-LS2PostBuildPublish`, the exact vendoring sequence is:

```powershell
# Step 1: Create Modules\ subdirectory in the artefact
$modulesTarget = Join-Path $ArtefactRoot 'Modules'
New-Item -ItemType Directory -Path $modulesTarget -Force | Out-Null

# Step 2: Pinned versions table (the single source of truth for dep versions)
$vendorVersions = [ordered] @{
    PSWriteHTML = '1.41.0'
    PSCertutil  = '0.0.3'
}

# Step 3: Save-Module each dep into Modules\ at its pinned version
$nestedEntries = @()
foreach ($depName in $vendorVersions.Keys) {
    $pinned = $vendorVersions[$depName]
    Save-Module -Name $depName -RequiredVersion $pinned -Path $modulesTarget -Force

    # Step 4: Discover the actual version subfolder name Save-Module created
    $ver = (Get-ChildItem (Join-Path $modulesTarget $depName) |
            Sort-Object Name -Descending |
            Select-Object -First 1).Name

    # Step 5: Build the NestedModules path string
    $nestedEntries += "Modules\$depName\$ver\$depName.psm1"
}

# Step 6: Patch the ARTEFACT PSD1 (not the source PSD1) with NestedModules
$psd1 = Join-Path $ArtefactRoot 'Locksmith2.psd1'
Update-ModuleManifest -Path $psd1 -NestedModules $nestedEntries
```

**Resulting artefact structure** (inferred from `Save-Module` output convention and `Update-ModuleManifest`):

```
Artefacts/Unpacked/Locksmith2/
├── Locksmith2.psd1              ← NestedModules patched by post-build step
├── Locksmith2.psm1              ← merged PSM1 (MergeModuleOnBuild was used)
├── Classes/
│   ├── LS2Principal.ps1         ← ScriptsToProcess (from source ScriptsToProcess field)
│   ├── LS2AdcsObject.ps1
│   └── LS2Issue.ps1
└── Modules/
    ├── PSWriteHTML/
    │   └── 1.41.0/
    │       ├── PSWriteHTML.psd1
    │       ├── PSWriteHTML.psm1
    │       └── … (full module tree)
    └── PSCertutil/
        └── 0.0.3/
            ├── PSCertutil.psd1
            └── PSCertutil.psm1
```

**Patched artefact PSD1 NestedModules** (written by `Update-ModuleManifest`):
```powershell
NestedModules = @(
    'Modules\PSWriteHTML\1.41.0\PSWriteHTML.psm1',
    'Modules\PSCertutil\0.0.3\PSCertutil.psm1'
)
```

**Source PSD1 has none of this** — `Locksmith2.psd1` in the repo root contains only built-in `ExternalModuleDependencies` and `RequiredModules` (the Microsoft.PowerShell.* modules). PSCertutil does not appear in the source PSD1 at all.

### Why `Publish-Module -Path` (not `-Name`) is essential

```powershell
# Locksmith2/Build/Invoke-LS2PostBuildPublish.ps1
Publish-Module -Path $ArtefactRoot -NuGetApiKey $apiKey -Repository 'PSGallery' -Force
```

If you used `-Name 'Locksmith2'`, PowerShell would resolve the module from `$env:PSModulePath` and publish whatever is installed there — which is the pre-vendoring copy without the `Modules\` directory. Using `-Path $ArtefactRoot` publishes exactly the directory on disk, including the vendored `Modules\PSCertutil\` tree and the patched PSD1 with NestedModules.

**Important note from the source comment**:
```
# NOTE: Publishing is intentionally NOT configured inside Build-Module {}.
# PSPublishModule's Publish-Module call uses -Name (resolves from PSModulePath),
# which publishes the pre-vendoring copy of the module and excludes PSWriteHTML
# and PSCertutil. We publish via -Path after vendoring instead (see below).
```
This means: do NOT use `New-ConfigurationPublish` inside `Build-Module {}` when vendoring is involved — PSPublishModule's built-in publish runs too early.

---

## 3. Recommended settings for ADCSGoat's `Build/Build-Module.ps1`

### 3a. PSCertutil — vendor post-build (exact Locksmith2 adaptation)

**Top of Build-Module.ps1 (before `Build-Module {}`):**
```powershell
# Install PSCertutil for build-time static analysis only.
# (AutomatedLab is intentionally skipped here — too large for CI, and IgnoreModuleName handles it.)
foreach ($depName in @('PSCertutil')) {
    if (-not (Get-Module -Name $depName -ListAvailable)) {
        Write-Host "Installing $depName for build-time analysis..."
        Install-Module -Name $depName -Scope CurrentUser -Force -AllowClobber
    }
}
```

**Inside `Build-Module {}` block:**
```powershell
# PSCertutil: vendored post-build into Modules\ — skip static analysis.
# AutomatedLab + PSFramework: optional soft deps, not vendorable — skip.
New-ConfigurationModuleSkip -IgnoreModuleName 'PSCertutil', 'AutomatedLab', 'PSFramework'
```

**Do NOT add any of these to `New-ConfigurationModule`.** PSCertutil is not an ExternalModule, not a RequiredModule, not an ApprovedModule in the build configuration.

**After `Build-Module {}` closes (in a companion `Invoke-AGPostBuildPublish.ps1`):**
```powershell
function Invoke-AGPostBuildPublish {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$ArtefactRoot,
        [switch]$PublishToPSGallery,
        [string]$PSGalleryAPIKey,
        [string]$PSGalleryAPIPath
    )

    # ── Vendor PSCertutil ──────────────────────────────────────────────────────
    Write-Host '[i] Vendoring PSCertutil into artefact' -ForegroundColor Cyan

    $modulesTarget = Join-Path $ArtefactRoot 'Modules'
    New-Item -ItemType Directory -Path $modulesTarget -Force | Out-Null

    $vendorVersions = [ordered] @{
        PSCertutil = '0.0.3'   # Bump deliberately — see Invoke-LS2PostBuildPublish for precedent
    }

    $nestedEntries = @()
    foreach ($depName in $vendorVersions.Keys) {
        $pinned = $vendorVersions[$depName]
        Write-Host "   [>] Saving $depName $pinned from PSGallery..." -ForegroundColor Yellow
        Save-Module -Name $depName -RequiredVersion $pinned -Path $modulesTarget -Force
        $ver = (Get-ChildItem (Join-Path $modulesTarget $depName) |
                Sort-Object Name -Descending | Select-Object -First 1).Name
        Write-Host "   [+] Vendored $depName $ver" -ForegroundColor Green
        $nestedEntries += "Modules\$depName\$ver\$depName.psm1"
    }

    $psd1 = Join-Path $ArtefactRoot 'ADCSGoat.psd1'
    Update-ModuleManifest -Path $psd1 -NestedModules $nestedEntries
    Write-Host "[+] ADCSGoat.psd1 patched — NestedModules = $($nestedEntries -join ', ')" -ForegroundColor Green

    # ── Copy Private\Template\*.xml into artefact ──────────────────────────────
    # PSPublishModule does not copy non-.ps1 files from Private\.
    # Install-ADCSGoat.ps1 loads these via Import-Clixml at runtime.
    # (See §4 of this document for full explanation.)
    Write-Host '[i] Copying Private\Template data files into artefact' -ForegroundColor Cyan
    $templateSrc = Join-Path $PSScriptRoot '..\ADCSGoat\Private\Template'
    $templateDst = Join-Path $ArtefactRoot 'Private\Template'
    New-Item -ItemType Directory -Path $templateDst -Force | Out-Null
    Copy-Item -Path (Join-Path $templateSrc '*.xml') -Destination $templateDst -Force
    Copy-Item -Path (Join-Path $templateSrc '*.json') -Destination $templateDst -Force
    Write-Host '[+] Template files copied' -ForegroundColor Green

    # ── Publish from artefact path (not -Name) ─────────────────────────────────
    if (-not $PublishToPSGallery) { return }

    # ... (same pattern as Locksmith2's Invoke-LS2PostBuildPublish)
    $publishParams = @{
        Path        = $ArtefactRoot
        NuGetApiKey = $apiKey
        Repository  = 'PSGallery'
        Force       = $true
        ErrorAction = 'Stop'
    }
    Publish-Module @publishParams
}
```

**Invocation at bottom of Build-Module.ps1:**
```powershell
. "$PSScriptRoot\Invoke-AGPostBuildPublish.ps1"

$postBuildParams = @{
    ArtefactRoot       = Join-Path $PSScriptRoot '..\Artefacts\Unpacked\ADCSGoat'
    PublishToPSGallery = $PublishToPSGallery
}
if ($PSGalleryAPIKey)  { $postBuildParams['PSGalleryAPIKey']  = $PSGalleryAPIKey }
if ($PSGalleryAPIPath) { $postBuildParams['PSGalleryAPIPath'] = $PSGalleryAPIPath }

Invoke-AGPostBuildPublish @postBuildParams
```

### 3b. AutomatedLab and PSFramework — skip, no vendoring

```powershell
# Inside Build-Module {} — already covered by the combined ModuleSkip call above.
# Do NOT install AutomatedLab for build-time analysis (too large; CI-hostile).
# Do NOT add AutomatedLab or PSFramework to New-ConfigurationModule in any Type.
# Do NOT add them to RequiredModules in New-ConfigurationManifest.
```

Document in the module README and/or in the `Deploy-AGInfrastructure` function's `.SYNOPSIS` that this function requires AutomatedLab ≥ 5.x installed separately, with Hyper-V and administrator rights.

### 3c. Microsoft built-in modules — ExternalModule

```powershell
New-ConfigurationModule -Type ExternalModule -Name @(
    'Microsoft.PowerShell.Utility',
    'Microsoft.PowerShell.Management',
    'Microsoft.PowerShell.Security'
)
```

`Microsoft.PowerShell.Archive` and `PowerShellGet` are not called by any ADCSGoat function and can be omitted (unlike Locksmith2, which uses archive/packaging functions). `CimCmdlets` is also unused.

---

## 4. Private/Template file inclusion

### What the files are and which are runtime-critical

```
ADCSGoat/Private/Template/
  ESC1.json   ESC1.ps1   ESC1.xml      ← one set per ESC scenario (×6)
  ESC2.json   ESC2.ps1   ESC2.xml
  ESC3c1.json ESC3c1.ps1 ESC3c1.xml
  ESC3c2.json ESC3c2.ps1 ESC3c2.xml
  ESC4.json   ESC4.ps1   ESC4.xml
  ESC9.json   ESC9.ps1   ESC9.xml
```

| Extension | Role | Runtime-required? |
|-----------|------|------------------|
| `.xml` | CliXml-serialised hashtable. Loaded at runtime: `Import-Clixml -Path $PropertiesPath` | **YES — critical** |
| `.ps1` | PowerShell hashtable literal (`$ESC1 = @{…}`); likely used to generate the `.xml` via `Export-Clixml`. Not dot-sourced or called at runtime | No (build-time / authoring artifact) |
| `.json` | Same data in JSON; not referenced by any module function | No |

Evidence: `ADCSGoat/Public/Install-ADCSGoat.ps1:22-24`:
```powershell
$PropertiesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\Private\Template\$($_.ESC).xml"
$Properties = Import-Clixml -Path $PropertiesPath
Set-AGTemplateProperty -TemplateName $_.Name -Properties $Properties -Server $Server
```

### What PSPublishModule 2.0.27 outputs after MergeModuleOnBuild

From `Stepper/Artefacts/Unpacked/Stepper/` (ground-truth):
```
Stepper.psd1
Stepper.psm1
Images/           ← root-level directory peer to Private/Public: COPIED
  Stepper.png
```

`Private/` and `Public/` are **absent** — their `.ps1` files were merged into `Stepper.psm1`. Any file inside `Private/` that is not a `.ps1` is silently omitted. The `.xml` and `.json` files in `ADCSGoat/Private/Template/` will NOT appear in the artefact automatically.

### The `$PSScriptRoot` path problem with MergeModuleOnBuild

`Install-ADCSGoat.ps1` constructs the path:
```powershell
$PropertiesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\Private\Template\$($_.ESC).xml"
```

| Scenario | `$PSScriptRoot` value | Resolved path | Status |
|----------|-----------------------|---------------|--------|
| Running from source (no build) | `…/ADCSGoat/Public/` | `…/ADCSGoat/Private/Template/ESC1.xml` | ✅ Works |
| After MergeModuleOnBuild (artefact) | Artefact root (where `ADCSGoat.psm1` lives) | `<artefact-parent>/Private/Template/ESC1.xml` — goes **above** artefact | ❌ Broken |
| Without merge (source files kept) | `…/artefact/Public/` | `…/artefact/Private/Template/ESC1.xml` | ✅ Works — IF files are present |

### Recommended approach — two-part solution

**Part A: Do not enable `MergeModuleOnBuild` until `Install-ADCSGoat.ps1` is updated.**

Without merge, each function's `$PSScriptRoot` still points to its source file's directory (`Public/`), so the `"..\Private\Template\"` path continues to resolve correctly — provided the `Private/Template/` directory is present in the artefact.

```powershell
# In Build-Module {} — NOTE: MergeModuleOnBuild intentionally omitted
New-ConfigurationBuild -Enable:$true -SignModule:$false `
    -DeleteTargetModuleBeforeBuild `
    -DoNotAttemptToFixRelativePaths -UseWildcardForFunctions
```

**Part B: Copy `.xml` (and optionally `.json`) in the post-build step.**

Even without merge, PSPublishModule may not copy non-`.ps1` files from `Private/`. The post-build `Invoke-AGPostBuildPublish` function (see §3a above) handles this with:
```powershell
Copy-Item -Path (Join-Path $templateSrc '*.xml') -Destination $templateDst -Force
Copy-Item -Path (Join-Path $templateSrc '*.json') -Destination $templateDst -Force
```

**Long-term fix (future ticket — not this ticket):** Move `Private/Template/` to `Template/` at the module root and update `Install-ADCSGoat.ps1` to use `"Template\$($_.ESC).xml"`. PSPublishModule would then automatically copy `Template/` as a root-level directory (same as Stepper's `Images/`), and `MergeModuleOnBuild` could be safely re-enabled.

### What happens to the Template `.ps1` files with and without merge

| Mode | Effect on `ESC1.ps1` etc. |
|------|--------------------------|
| No merge | Files copied to `Private/Template/` in artefact as-is; harmless |
| MergeModuleOnBuild | Files merged into the PSM1 as variable assignments (`$ESC1 = @{…}`) — these become module-scope variables, polluting the module's namespace. Not a runtime error but untidy |

This is another reason to omit `MergeModuleOnBuild` for now.

---

## 5. `New-ConfigurationModuleSkip` — full recommendation

```powershell
New-ConfigurationModuleSkip -IgnoreModuleName 'PSCertutil', 'AutomatedLab', 'PSFramework'
```

| Module | Why skipped |
|--------|------------|
| `PSCertutil` | Vendored post-build into `Modules\PSCertutil\`; PSPublishModule must not try to copy/inline it during analysis |
| `AutomatedLab` | Optional soft dep; Windows-only; has DLLs; cannot be merged or vendored; build must not error on its function calls |
| `PSFramework` | Used via `[PsfValidatePattern]` attribute and `Write-PSFHostColor` / `Get-PSFUserChoice` in `Deploy-AGInfrastructure.ps1`; same reasons as AutomatedLab |

**PSCertutil must still be installed on the build machine** before `Build-Module {}` runs (Phase 1 pre-flight above), so that PSPublishModule's analyser can attribute `Enable-PSCEditFlag` etc. to the correct module and apply `IgnoreModuleName` correctly. This is also confirmed by the Locksmith2 comment:
```powershell
# Ensure vendored dependencies are available so PSPublishModule can resolve
# function calls to their source module during analysis (required for
# New-ConfigurationModuleSkip -IgnoreModuleName to match correctly).
```

**Do NOT install AutomatedLab** in the build pre-flight — it is too large for CI and `IgnoreModuleName` bypasses the need to resolve its functions.

---

## 6. PSPublishModule 2.0.27 pitfalls for ADCSGoat

### P1. `MergeModuleOnBuild` + `$PSScriptRoot`-relative XML paths → silent runtime failure
The most critical pitfall. `Import-Clixml` silently fails (or throws a path-not-found error) because after merge `$PSScriptRoot` is the artefact root, not `Public/`. Do not enable merge until the path in `Install-ADCSGoat.ps1` is corrected.

### P2. PSPublishModule does not copy non-`.ps1` files from `Private/`
Confirmed by Stepper artefact inspection. The `.xml` CliXml files are silently omitted. A post-build copy step is mandatory in all build modes.

### P3. Private/Template `.ps1` data files pollute module scope when merged
With `MergeModuleOnBuild` the six `$ESC1 = @{…}` etc. files become orphaned module-scope variable assignments. Not a runtime error but creates undocumented module-scope variables. Resolved by long-term fix (move Template to module root).

### P4. `Publish-Module -Name` ships the pre-vendoring copy
If `New-ConfigurationPublish` is used inside `Build-Module {}`, PSPublishModule publishes from `$env:PSModulePath` — which is the copy without `Modules\PSCertutil\`. The Locksmith2 `NOTE` comment in `Build-Module.ps1` explicitly documents this trap. Do NOT use `New-ConfigurationPublish`; use `Publish-Module -Path $ArtefactRoot` in the post-build script.

### P5. `DefaultPSD1` formatting produces mixed CRLF/LF → PSScriptAnalyzer throws
Both Locksmith2 and Stepper have already worked around this. Do not include `'DefaultPSD1'` in any `New-ConfigurationFormat -ApplyTo` call. Use only `'OnMergePSD1'` and `'DefaultPSM1'`.

### P6. VS Code host / PSScriptAnalyzer assembly double-load
Running `Build-Module.ps1` from the VS Code PowerShell Extension terminal loads a second copy of the PSScriptAnalyzer assembly and throws. Use the `pwsh -NoProfile -File` re-invocation guard already present in both reference repos.

### P7. AutomatedLab as `RequiredModule` blocks all non-lab users
If AutomatedLab appeared in `RequiredModules`, PowerShell would refuse to import ADCSGoat unless AutomatedLab is pre-installed. Since only `Deploy-AGInfrastructure` needs it, this would be hostile to users who just want `Install-ADCSGoat`. Keep it out of the manifest entirely and document it as a soft requirement.

### P8. PSCertutil version drift without pinning
The post-build `Save-Module` call must use `-RequiredVersion`. If omitted it pulls the latest published version, which may have breaking changes. Locksmith2 pins to `0.0.3`. ADCSGoat should adopt the same pin and bump it deliberately after testing.

---

## 7. Consolidated recommended lines for `Build/Build-Module.ps1`

```powershell
# ── Pre-flight: install PSCertutil for build-time analysis ────────────────
# (BEFORE Build-Module {} — PSPublishModule needs it to attribute function calls)
foreach ($depName in @('PSCertutil')) {
    if (-not (Get-Module -Name $depName -ListAvailable)) {
        Write-Host "Installing $depName for build-time static analysis..."
        Install-Module -Name $depName -Scope CurrentUser -Force -AllowClobber
    }
}

Build-Module -ModuleName 'ADCSGoat' {

    New-ConfigurationManifest @Manifest   # (defined above; no PSCertutil/AutomatedLab in it)

    # Built-in PowerShell modules only
    New-ConfigurationModule -Type ExternalModule -Name @(
        'Microsoft.PowerShell.Utility',
        'Microsoft.PowerShell.Management',
        'Microsoft.PowerShell.Security'
    )

    # PSCertutil  → vendored post-build; skip analysis
    # AutomatedLab → soft dep; not vendorable; skip analysis
    # PSFramework  → soft dep via AutomatedLab; skip analysis
    New-ConfigurationModuleSkip -IgnoreModuleName 'PSCertutil', 'AutomatedLab', 'PSFramework'

    New-ConfigurationFormat -ApplyTo 'DefaultPSM1' -EnableFormatting -Sort None
    New-ConfigurationFormat -ApplyTo 'OnMergePSD1' -PSD1Style 'Minimal'
    # NOTE: 'DefaultPSD1' intentionally excluded — PSScriptAnalyzer CRLF/LF bug

    New-ConfigurationDocumentation -Enable:$false -StartClean -UpdateWhenNew `
        -PathReadme 'Docs\Readme.md' -Path 'Docs'

    New-ConfigurationImportModule -ImportSelf -ImportRequiredModules

    # NOTE: MergeModuleOnBuild intentionally omitted until Install-ADCSGoat.ps1
    # $PSScriptRoot path is corrected to work from the module root.
    New-ConfigurationBuild -Enable:$true -SignModule:$false `
        -DeleteTargetModuleBeforeBuild `
        -DoNotAttemptToFixRelativePaths -UseWildcardForFunctions

    New-ConfigurationArtefact -Type Unpacked -Enable -Path "$PSScriptRoot\..\Artefacts\Unpacked"
    New-ConfigurationArtefact -Type Packed   -Enable -Path "$PSScriptRoot\..\Artefacts\Packed" `
        -IncludeTagName

    # NOTE: New-ConfigurationPublish intentionally absent.
    # Publishing after vendoring uses Publish-Module -Path in the post-build step.
}

# ── Post-build: vendor PSCertutil + copy Template files ──────────────────
. "$PSScriptRoot\Invoke-AGPostBuildPublish.ps1"

$postBuildParams = @{
    ArtefactRoot       = Join-Path $PSScriptRoot '..\Artefacts\Unpacked\ADCSGoat'
    PublishToPSGallery = $PublishToPSGallery
}
if ($PSGalleryAPIKey)  { $postBuildParams['PSGalleryAPIKey']  = $PSGalleryAPIKey }
if ($PSGalleryAPIPath) { $postBuildParams['PSGalleryAPIPath'] = $PSGalleryAPIPath }

Invoke-AGPostBuildPublish @postBuildParams
```

---

## 8. Differences between ADCSGoat and Locksmith2 vendoring

| Aspect | Locksmith2 | ADCSGoat |
|--------|-----------|---------|
| Modules vendored | PSWriteHTML + PSCertutil | PSCertutil only |
| Pinned versions | PSWriteHTML 1.41.0, PSCertutil 0.0.3 | PSCertutil 0.0.3 (inherit Locksmith2 pin) |
| Pre-flight installs | PSWriteHTML + PSCertutil | PSCertutil only |
| `MergeModuleOnBuild` | Yes | **No** (blocked by Template XML path issue) |
| Extra post-build copy | None | `Private\Template\*.xml` and `*.json` |
| `New-ConfigurationPublish` inside Build-Module | Absent (same trap documented) | Absent |
| Publish mechanism | `Publish-Module -Path $ArtefactRoot` | Same |

---

## 9. Open questions / flags for next ticket

| Question | Recommended owner |
|----------|------------------|
| Should `MergeModuleOnBuild` be enabled now by updating the `$PSScriptRoot` path in `Install-ADCSGoat.ps1`, or deferred? | Maintainer decision |
| If path is updated, should Template files move to module root (`ADCSGoat/Template/`) so PSPublishModule copies them automatically? | Implementation ticket |
| Should `Deploy-AGInfrastructure` be moved to a separate optional module or script to cleanly isolate the AutomatedLab/PSFramework dependency? | Maintainer decision |
| Should `PrivateData.PSData.ExternalModuleDependencies` mention AutomatedLab informationally even though it's not in RequiredModules? | Implementer |
| PSCertutil pin: stay at `0.0.3` (Locksmith2 precedent) or evaluate newer version? | Maintainer |
```