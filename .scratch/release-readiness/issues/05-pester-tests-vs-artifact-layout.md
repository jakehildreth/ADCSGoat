# Pester tests vs artifact layout

Type: grilling
Status: open
Blocked by: 03, 04

## Question

Update the Pester tests to target the current artifact layout, or restore the documented output contract?

Current tests expect `Output/ADCSGoat/<version>/ADCSGoat.psd1`, which the build did not produce. Blocked until the canonical artifact layout (03) and version stamping (04) are decided — the tests encode whichever layout wins.
