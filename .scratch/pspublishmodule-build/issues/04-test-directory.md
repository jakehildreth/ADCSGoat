## Question

Should the test directory stay as `./tests/` or be renamed to `./Tests/` to match the reference repos? And should Pester configuration move into `Build-Module.ps1`/CI or stay as standalone config?

Locksmith2 and Stepper use `./Tests/` (capital T). ADCSGoat currently uses `./tests/` with `ScriptAnalyzerSettings.psd1` and Pester tests there.

## Answer

Rename `./tests/` to `./Tests/` and move `ScriptAnalyzerSettings.psd1` into it. CI will run Pester from `./Tests/`. Use a git-aware case rename to avoid issues on case-insensitive filesystems.

Type: grilling
Status: resolved
