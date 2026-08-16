# Artifact version matches -CalVer

Type: grilling
Status: open

## Question

How do we guarantee the generated artifact contains exactly the module version requested by `-CalVer`?

The audit requested `2026.8.121930`; the artifact manifest read back `2026.7.220807`. Decide where the version gets stamped, why the requested version was ignored, and what verification proves the artifact version matches.
