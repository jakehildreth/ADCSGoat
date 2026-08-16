# Artifact directory cleaning

Type: grilling
Status: resolved

## Question

How should the build clean its artifact directories reliably?

The audit observed PSPublishModule emitting deletion warnings and leaving a duplicate nested module layout. Decide: a pre-clean step in the build script, PSPublishModule configuration, or replacing the cleaning behavior outright. The answer defines the canonical artifact layout that tickets 05 and 09 verify against.

## Answer

**Pre-clean in the build script, plus an upstream bug report (option C), nuking everything.**

Root cause, reproduced live on 2026-08-16: PSPublishModule's `Remove-ItemAlternative` helper throws `Value cannot be null. (Parameter 'type')` on macOS, so every delete fails with a WARNING and the copy step then nests the fresh module inside the stale folder — byte-identical duplicates at `Artefacts/<Type>/ADCSGoat/ADCSGoat/`, which also ship inside the Packed zip.

The fix, when executed:

- `Build-Module.ps1` deletes the contents of `Artefacts/Unpacked/` and `Artefacts/Packed/` with `Remove-Item -Recurse -Force -ErrorAction Stop` *before* `Build-Module` runs. Old zips are destroyed too — full nuke, no preservation.
- A failed clean fails the build (per ticket 02's exit-code hardening).
- Scope: only `Artefacts/`, which is gitignored build output. Source is never touched.
- Report the `Remove-ItemAlternative` failure upstream to PSPublishModule.

Canonical artifact layout after cleaning (for tickets 05 and 09): `Artefacts/Unpacked/ADCSGoat/{ADCSGoat.psd1, ADCSGoat.psm1, Public/, Private/, Modules/, en-US/, LICENSE}` — no nested `ADCSGoat/ADCSGoat/`; `Artefacts/Packed/` contains the versioned zip.
