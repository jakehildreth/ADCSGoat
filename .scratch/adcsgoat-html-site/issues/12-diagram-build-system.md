# 12 — Diagram build system

**What to build:** Produce the attack-path diagrams as static SVGs from text-based Mermaid sources, and provide a script to regenerate them. The generated files are ready to embed in path pages.

**Blocked by:** 09 — Module scaffold and cmdlets

**Status:** ready-for-agent

- [ ] `Build/Build-Diagrams.ps1` runs `mmdc` against every `.mmd` file and outputs `.svg` under `Assets/diagrams/`.
- [ ] Mermaid source files exist for all 10 attack paths with consistent semantic color classes.
- [ ] Generated SVGs are self-contained and display correctly when opened from disk.
- [ ] `Build/` is excluded from the PSPublishModule package.
