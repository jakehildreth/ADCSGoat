# Stale help placeholders

Type: grilling
Status: open
Blocked by: 07

## Question

Remove the stale generated-help placeholders, or regenerate valid help from source comments?

Placeholders like `{{ Fill Randomize Description }}` ship in the module. Blocked by the `-Randomize` decision (07): if the parameter is removed, its placeholder dies with it; if implemented, the help gets written for real.
