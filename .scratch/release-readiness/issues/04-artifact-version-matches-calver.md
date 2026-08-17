# Artifact version matches -CalVer

Type: grilling
Status: resolved

## Question

How do we guarantee the generated artifact contains exactly the module version requested by `-CalVer`?

The audit requested `2026.8.121930`; the artifact manifest read back `2026.7.220807`. Decide where the version gets stamped, why the requested version was ignored, and what verification proves the artifact version matches.

## Answer

**The requested version was never ignored — the audit read a stale artifact.** Reproduced on 2026-08-16: the fresh top-level artifact carried today's correct version (`2026.8.161031`), while the stale nested copy left by the broken delete (ticket 03) carried `2026.7.220807` — the exact version the audit read back. `Artefacts/Packed/` even contained `ADCSGoat.v2026.8.121930.zip`: the audit's requested build succeeded and zipped correctly.

Decisions:

1. **Post-build version assertion** in `Invoke-AGPostBuildPublish`: read the artifact manifest's `ModuleVersion`, compare against the requested version, `throw` on mismatch. Turns the audit's manual read-back into an automated gate and catches any future stamping regression. Ticket 03's pre-clean removes the stale-artifact failure class; this assertion is the backstop.
2. **Source-manifest stamping stays as-is.** The build stamps the source `ADCSGoat.psd1` on every run; that stamp *is* the ticket-01 back-write, committed only at release time. Local builds dirty the tree — restore with `git checkout -- ADCSGoat.psd1` when not releasing. No release-mode distinction, no upstream investigation.
