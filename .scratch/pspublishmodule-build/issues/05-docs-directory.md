## Question

Should documentation stay under `./docs/en-US/` or move to `./Docs/` (capital D) to match the reference repos?

PSPublishModule has `New-ConfigurationDocumentation` options. The current docs are function help markdown files. This decision affects `Build-Module.ps1` and whether doc generation is enabled.

## Answer

Rename `./docs/` to `./Docs/` (capital D) and keep existing `en-US/` content inside (`./Docs/en-US/`). Disable PSPublishModule's `New-ConfigurationDocumentation` generation so hand-written help files are not overwritten.

Type: grilling
Status: resolved
