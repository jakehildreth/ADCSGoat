# Artifact directory cleaning

Type: grilling
Status: open

## Question

How should the build clean its artifact directories reliably?

The audit observed PSPublishModule emitting deletion warnings and leaving a duplicate nested module layout. Decide: a pre-clean step in the build script, PSPublishModule configuration, or replacing the cleaning behavior outright. The answer defines the canonical artifact layout that tickets 05 and 09 verify against.
