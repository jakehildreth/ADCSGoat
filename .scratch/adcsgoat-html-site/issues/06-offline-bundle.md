## Question

What is the folder structure and packaging for the offline-distributed site bundle?

Type: task
Status: resolved

## Answer

The HTML site ships inside the PowerShell module itself, not as a separate ZIP.

Module layout:

```text
ADCSGoat/
├── ADCSGoat.psd1
├── ADCSGoat.psm1
├── README.md                     # explains Start-ADCSGoatSite
├── Public/
│   ├── Start-ADCSGoatSite.ps1  # opens Assets/index.html
│   └── Get-ADCSGoatSitePath.ps1
├── Build/
│   └── Build-Diagrams.ps1        # Mermaid -> SVG; excluded from package
└── Assets/
    ├── index.html
    ├── setup.html
    ├── prerequisites.html
    ├── tools.html
    ├── references.html
    ├── css/
    ├── js/
    ├── fonts/
    ├── diagrams/
    └── paths/
```

Notes:
- `Assets/` is included by PSPublishModule 2.0.27 by default.
- `Build/` is excluded from the published package.
- Only generated `.svg` diagrams ship; `.mmd` sources stay in repo/Build.
- Cmdlets resolve paths relative to the module base.
- Module README tells students to run `Start-ADCSGoatSite`.
