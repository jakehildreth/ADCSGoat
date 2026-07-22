# Wayfinder Map: ADCSGoat HTML Site

## Destination

A clear, decision-complete spec for a multi-page, offline-distributed HTML site that teaches ADCSGoat lab users the attack paths, plus setup, prerequisites, tools, and remediation. The spec is ready to hand to `/to-spec`.

## Notes

- Source content: `/Users/jhildreth/Library/Mobile Documents/iCloud~md~obsidian/Documents/talks/WWHF 2026/A Goat, an ESCalator, and a Locksmith - An AD CS Education in Three Acts/Tool Updates/ADCSGoat.md`
- Tech constraints: plain HTML/CSS/JS, minimal JS, offline bundle, light/dark theme switch, bundled Berkeley Mono font.
- Interactivity requirements: sidebar nav, difficulty filters, search, expandable details, progress checkboxes.
- Audience: students / lab users.
- Diagrams: choose easiest-to-maintain format.

## Decisions so far

<!-- the index — one line per closed ticket: enough to judge relevance, then zoom the link for the detail the ticket holds -->

- [Accessibility and print styling](./issues/07-accessibility-print.md) — semantic HTML + CSS custom properties + ~55 lines of vanilla JS; print block hides chrome and expands `<details>`.
- [Diagram format](./issues/04-diagram-format.md) — Mermaid CLI rendered to static SVG at build time; source `.mmd` files committed alongside generated `.svg`.
- [Site structure](./issues/01-site-structure.md) — multi-page hierarchy under `paths/` by difficulty; each path page includes a Remediation section.
- [Theme implementation](./issues/02-theme-implementation.md) — CSS custom properties + `prefers-color-scheme` default + manual toggle + localStorage; Berkeley Mono loaded from `fonts/` with system-monospace fallback; ski-slope difficulty badges in theme.
- [Minimal-JS interactivity](./issues/03-minimal-js-interactivity.md) — sidebar via CSS-only mobile toggle; native `<details>`; no filters, no search, no progress checkboxes; only JS is the theme toggle.
- [Content template](./issues/05-content-template.md) — 9-section template for every attack path page; all commands in PowerShell; remediation includes CLI + GUI fix steps and Detection Ideas.
- [Offline bundle](./issues/06-offline-bundle.md) — site ships inside PowerShell module under `Assets/`; `Build/` excluded; module README + `Start-ADCSGoatSite` cmdlet.

## Not yet specified

- (none — map complete)

## Handoff

- Spec written to [spec.md](./spec.md)
- Ready for `/to-spec`

## Out of scope

- Actual content authoring beyond the spec template examples
- Online hosting / CI-CD
- Backend or dynamic features
